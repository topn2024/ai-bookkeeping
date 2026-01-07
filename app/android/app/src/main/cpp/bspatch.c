/*
 * bspatch.c - Binary patch application implementation
 *
 * Based on bsdiff 4.3 by Colin Percival
 * Copyright 2003-2005 Colin Percival
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.
 */

#include "bspatch.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/types.h>
#include <zlib.h>

/* BSDIFF header magic */
static const char BSDIFF_MAGIC[] = "BSDIFF40";

/* Error messages */
static const char* error_messages[] = {
    "Success",
    "Cannot open old file",
    "Cannot read old file",
    "Cannot open patch file",
    "Invalid patch header",
    "Patch header corrupt",
    "Cannot decompress ctrl block",
    "Cannot decompress diff block",
    "Cannot decompress extra block",
    "Cannot create new file",
    "Memory allocation failed",
    "Corrupt patch"
};

const char* bspatch_strerror(int error_code) {
    if (error_code >= 0) return error_messages[0];
    int idx = -error_code;
    if (idx >= sizeof(error_messages) / sizeof(error_messages[0])) {
        return "Unknown error";
    }
    return error_messages[idx];
}

/* Read 8-byte signed integer (little-endian) */
static int64_t offtin(uint8_t *buf) {
    int64_t y;

    y = buf[7] & 0x7F;
    y = y * 256; y += buf[6];
    y = y * 256; y += buf[5];
    y = y * 256; y += buf[4];
    y = y * 256; y += buf[3];
    y = y * 256; y += buf[2];
    y = y * 256; y += buf[1];
    y = y * 256; y += buf[0];

    if (buf[7] & 0x80) y = -y;

    return y;
}

/* Decompress gzip data */
static int decompress_gzip(uint8_t *in, size_t in_len, uint8_t **out, size_t *out_len) {
    z_stream strm;
    uint8_t *buf = NULL;
    size_t buf_len = in_len * 4;  /* Initial guess */
    int ret;

    /* Allocate initial buffer */
    buf = malloc(buf_len);
    if (!buf) return -1;

    /* Initialize zlib stream */
    memset(&strm, 0, sizeof(strm));
    strm.next_in = in;
    strm.avail_in = in_len;

    /* Use inflateInit2 with 16+MAX_WBITS for gzip format */
    ret = inflateInit2(&strm, 16 + MAX_WBITS);
    if (ret != Z_OK) {
        free(buf);
        return -1;
    }

    /* Decompress */
    size_t total_out = 0;
    do {
        /* Expand buffer if needed */
        if (total_out >= buf_len) {
            buf_len *= 2;
            uint8_t *new_buf = realloc(buf, buf_len);
            if (!new_buf) {
                free(buf);
                inflateEnd(&strm);
                return -1;
            }
            buf = new_buf;
        }

        strm.next_out = buf + total_out;
        strm.avail_out = buf_len - total_out;

        ret = inflate(&strm, Z_NO_FLUSH);
        if (ret != Z_OK && ret != Z_STREAM_END) {
            free(buf);
            inflateEnd(&strm);
            return -1;
        }

        total_out = strm.total_out;
    } while (ret != Z_STREAM_END);

    inflateEnd(&strm);

    *out = buf;
    *out_len = total_out;
    return 0;
}

/* Read entire file into memory */
static int read_file(const char *path, uint8_t **data, size_t *size) {
    FILE *f = fopen(path, "rb");
    if (!f) return -1;

    fseek(f, 0, SEEK_END);
    *size = ftell(f);
    fseek(f, 0, SEEK_SET);

    *data = malloc(*size);
    if (!*data) {
        fclose(f);
        return -1;
    }

    if (fread(*data, 1, *size, f) != *size) {
        free(*data);
        fclose(f);
        return -1;
    }

    fclose(f);
    return 0;
}

/* Write data to file */
static int write_file(const char *path, uint8_t *data, size_t size) {
    FILE *f = fopen(path, "wb");
    if (!f) return -1;

    if (fwrite(data, 1, size, f) != size) {
        fclose(f);
        return -1;
    }

    fclose(f);
    return 0;
}

int bspatch(const char *old_path, const char *new_path, const char *patch_path) {
    FILE *f;
    uint8_t header[32];
    uint8_t *old = NULL;
    uint8_t *new_data = NULL;
    uint8_t *patch = NULL;
    size_t oldsize, newsize, patchsize;
    size_t bzctrllen, bzdatalen, bzdatalen_extra;
    uint8_t *ctrl = NULL, *diff = NULL, *extra = NULL;
    size_t ctrllen, difflen, extralen;
    int64_t ctrl_tuple[3];
    int64_t oldpos = 0, newpos = 0;
    int ret = 0;

    /* Read old file */
    if (read_file(old_path, &old, &oldsize) != 0) {
        return -1;  /* Cannot open old file */
    }

    /* Read patch file */
    if (read_file(patch_path, &patch, &patchsize) != 0) {
        free(old);
        return -3;  /* Cannot open patch file */
    }

    /* Check patch size */
    if (patchsize < 32) {
        free(old);
        free(patch);
        return -4;  /* Invalid patch header */
    }

    /* Parse header */
    memcpy(header, patch, 32);

    /* Check magic */
    if (memcmp(header, BSDIFF_MAGIC, 8) != 0) {
        free(old);
        free(patch);
        return -4;  /* Invalid patch header */
    }

    /* Read control block size, diff block size, and new file size */
    bzctrllen = offtin(header + 8);
    bzdatalen = offtin(header + 16);
    newsize = offtin(header + 24);

    /* Sanity check */
    if (bzctrllen < 0 || bzdatalen < 0 || newsize < 0 ||
        32 + bzctrllen + bzdatalen > patchsize) {
        free(old);
        free(patch);
        return -5;  /* Patch header corrupt */
    }

    bzdatalen_extra = patchsize - 32 - bzctrllen - bzdatalen;

    /* Decompress control block */
    if (decompress_gzip(patch + 32, bzctrllen, &ctrl, &ctrllen) != 0) {
        free(old);
        free(patch);
        return -6;  /* Cannot decompress ctrl block */
    }

    /* Decompress diff block */
    if (decompress_gzip(patch + 32 + bzctrllen, bzdatalen, &diff, &difflen) != 0) {
        free(old);
        free(patch);
        free(ctrl);
        return -7;  /* Cannot decompress diff block */
    }

    /* Decompress extra block */
    if (bzdatalen_extra > 0) {
        if (decompress_gzip(patch + 32 + bzctrllen + bzdatalen, bzdatalen_extra, &extra, &extralen) != 0) {
            free(old);
            free(patch);
            free(ctrl);
            free(diff);
            return -8;  /* Cannot decompress extra block */
        }
    } else {
        extra = malloc(1);
        extralen = 0;
    }

    /* Allocate new file buffer */
    new_data = malloc(newsize + 1);
    if (!new_data) {
        ret = -10;  /* Memory allocation failed */
        goto cleanup;
    }

    /* Apply patch */
    size_t ctrl_pos = 0;
    size_t diff_pos = 0;
    size_t extra_pos = 0;

    while (newpos < newsize) {
        /* Read control tuple */
        if (ctrl_pos + 24 > ctrllen) {
            ret = -11;  /* Corrupt patch */
            goto cleanup;
        }

        ctrl_tuple[0] = offtin(ctrl + ctrl_pos);
        ctrl_tuple[1] = offtin(ctrl + ctrl_pos + 8);
        ctrl_tuple[2] = offtin(ctrl + ctrl_pos + 16);
        ctrl_pos += 24;

        /* Sanity check */
        if (newpos + ctrl_tuple[0] > newsize) {
            ret = -11;
            goto cleanup;
        }

        /* Read diff block and add old data */
        if (diff_pos + ctrl_tuple[0] > difflen) {
            ret = -11;
            goto cleanup;
        }

        for (int64_t i = 0; i < ctrl_tuple[0]; i++) {
            if (oldpos + i >= 0 && oldpos + i < oldsize) {
                new_data[newpos + i] = diff[diff_pos + i] + old[oldpos + i];
            } else {
                new_data[newpos + i] = diff[diff_pos + i];
            }
        }

        diff_pos += ctrl_tuple[0];
        newpos += ctrl_tuple[0];
        oldpos += ctrl_tuple[0];

        /* Sanity check */
        if (newpos + ctrl_tuple[1] > newsize) {
            ret = -11;
            goto cleanup;
        }

        /* Read extra block */
        if (extra_pos + ctrl_tuple[1] > extralen) {
            ret = -11;
            goto cleanup;
        }

        memcpy(new_data + newpos, extra + extra_pos, ctrl_tuple[1]);
        extra_pos += ctrl_tuple[1];
        newpos += ctrl_tuple[1];
        oldpos += ctrl_tuple[2];
    }

    /* Write new file */
    if (write_file(new_path, new_data, newsize) != 0) {
        ret = -9;  /* Cannot create new file */
        goto cleanup;
    }

cleanup:
    free(old);
    free(patch);
    free(ctrl);
    free(diff);
    free(extra);
    free(new_data);

    return ret;
}
