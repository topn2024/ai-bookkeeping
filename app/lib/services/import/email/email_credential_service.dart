import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../models/email_account.dart';
import 'email_imap_service.dart';
import '../import_exceptions.dart';

/// 邮箱凭证安全存储服务
class EmailCredentialService {
  static const _storageKey = 'email_accounts';
  final FlutterSecureStorage _secureStorage;

  EmailCredentialService({
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// 获取所有已保存的邮箱账户
  Future<List<EmailAccount>> getAccounts() async {
    final jsonString = await _secureStorage.read(key: _storageKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    try {
      return EmailAccount.decodeList(jsonString);
    } catch (e) {
      return [];
    }
  }

  /// 保存邮箱账户
  Future<void> saveAccount(EmailAccount account) async {
    final accounts = await getAccounts();
    final existingIndex = accounts.indexWhere((a) => a.id == account.id);
    if (existingIndex >= 0) {
      accounts[existingIndex] = account;
    } else {
      accounts.add(account);
    }
    await _secureStorage.write(
      key: _storageKey,
      value: EmailAccount.encodeList(accounts),
    );
  }

  /// 删除邮箱账户
  Future<void> deleteAccount(String accountId) async {
    final accounts = await getAccounts();
    accounts.removeWhere((a) => a.id == accountId);
    await _secureStorage.write(
      key: _storageKey,
      value: EmailAccount.encodeList(accounts),
    );
  }

  /// 更新最后同步时间
  Future<void> updateLastSyncTime(String accountId) async {
    final accounts = await getAccounts();
    final index = accounts.indexWhere((a) => a.id == accountId);
    if (index >= 0) {
      accounts[index] = accounts[index].copyWith(
        lastSyncTime: DateTime.now(),
      );
      await _secureStorage.write(
        key: _storageKey,
        value: EmailAccount.encodeList(accounts),
      );
    }
  }

  /// 验证邮箱凭证（尝试 IMAP 连接）
  Future<bool> validateCredentials(EmailAccount account) async {
    final imapService = EmailImapService();
    try {
      await imapService.connect(account);
      await imapService.disconnect();
      return true;
    } on EmailAuthException {
      rethrow;
    } on EmailConnectionException {
      rethrow;
    } catch (e) {
      throw EmailConnectionException('验证失败: $e', originalError: e);
    }
  }
}
