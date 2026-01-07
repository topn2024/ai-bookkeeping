# -*- coding: utf-8 -*-
"""
添加家庭账本、NPS口碑、获客增长相关页面到原型
"""

import re

# 读取原型文件
with open('D:/code/ai-bookkeeping/docs/prototype/app_v2_full_prototype.html', 'r', encoding='utf-8') as f:
    content = f.read()

# SECTION 15: 家庭账本与多成员管理 (8个页面)
section_15 = '''
    <!-- ==================== SECTION 15: 家庭账本与多成员管理（8个页面）==================== -->
    <div id="family-ledger" class="section">
        <h2>SECTION 15: 家庭账本与多成员管理</h2>
        <div class="section-grid">

            <!-- 15.01 账本列表 -->
            <div class="phone-wrapper">
                <div class="phone-label">15.01 账本列表</div>
                <div class="phone-frame">
                    <div class="status-bar">
                        <span class="time">9:41</span>
                        <div class="icons">
                            <span class="material-icons">signal_cellular_alt</span>
                            <span class="material-icons">wifi</span>
                            <span class="material-icons">battery_full</span>
                        </div>
                    </div>
                    <div class="screen">
                        <!-- 页面头部 -->
                        <div class="page-header">
                            <div class="back-btn"><span class="material-icons">arrow_back</span></div>
                            <div class="page-header-title">我的账本</div>
                            <span class="material-icons">add</span>
                        </div>

                        <!-- 当前账本 -->
                        <div style="margin:16px;padding:16px;background:linear-gradient(135deg, #6495ED 0%, #4169E1 100%);border-radius:16px;color:white;">
                            <div style="display:flex;align-items:center;gap:12px;margin-bottom:12px;">
                                <div style="width:48px;height:48px;background:rgba(255,255,255,0.2);border-radius:12px;display:flex;align-items:center;justify-content:center;">
                                    <span class="material-icons" style="font-size:28px;">person</span>
                                </div>
                                <div style="flex:1;">
                                    <div style="font-size:16px;font-weight:600;">个人账本</div>
                                    <div style="font-size:12px;opacity:0.8;">当前使用中</div>
                                </div>
                                <span class="material-icons">check_circle</span>
                            </div>
                            <div style="display:flex;gap:16px;font-size:12px;opacity:0.9;">
                                <div>本月支出 <span style="font-weight:600;">¥3,280</span></div>
                                <div>交易 <span style="font-weight:600;">46笔</span></div>
                            </div>
                        </div>

                        <!-- 账本列表 -->
                        <div style="padding:0 16px;">
                            <div style="font-size:13px;font-weight:500;color:var(--on-surface-variant);margin-bottom:12px;">其他账本</div>

                            <!-- 家庭账本 -->
                            <div class="card" style="padding:16px;margin-bottom:12px;">
                                <div style="display:flex;align-items:center;gap:12px;">
                                    <div style="width:48px;height:48px;background:linear-gradient(135deg, #FFB74D 0%, #FFA726 100%);border-radius:12px;display:flex;align-items:center;justify-content:center;">
                                        <span class="material-icons" style="color:white;font-size:24px;">family_restroom</span>
                                    </div>
                                    <div style="flex:1;">
                                        <div style="font-size:15px;font-weight:500;">温馨小家</div>
                                        <div style="font-size:12px;color:var(--on-surface-variant);">家庭账本 · 3位成员</div>
                                    </div>
                                    <span class="material-icons" style="color:var(--on-surface-variant);">chevron_right</span>
                                </div>
                                <div style="display:flex;gap:8px;margin-top:12px;">
                                    <div style="width:28px;height:28px;border-radius:50%;background:#E3F2FD;display:flex;align-items:center;justify-content:center;font-size:12px;font-weight:500;color:#6495ED;">我</div>
                                    <div style="width:28px;height:28px;border-radius:50%;background:#FCE4EC;display:flex;align-items:center;justify-content:center;font-size:12px;">👩</div>
                                    <div style="width:28px;height:28px;border-radius:50%;background:#FFF3E0;display:flex;align-items:center;justify-content:center;font-size:12px;">👶</div>
                                </div>
                            </div>

                            <!-- 情侣账本 -->
                            <div class="card" style="padding:16px;margin-bottom:12px;">
                                <div style="display:flex;align-items:center;gap:12px;">
                                    <div style="width:48px;height:48px;background:linear-gradient(135deg, #F48FB1 0%, #EC407A 100%);border-radius:12px;display:flex;align-items:center;justify-content:center;">
                                        <span class="material-icons" style="color:white;font-size:24px;">favorite</span>
                                    </div>
                                    <div style="flex:1;">
                                        <div style="font-size:15px;font-weight:500;">甜蜜二人</div>
                                        <div style="font-size:12px;color:var(--on-surface-variant);">情侣账本 · 2位成员</div>
                                    </div>
                                    <span class="material-icons" style="color:var(--on-surface-variant);">chevron_right</span>
                                </div>
                            </div>

                            <!-- 旅行群组 -->
                            <div class="card" style="padding:16px;margin-bottom:12px;">
                                <div style="display:flex;align-items:center;gap:12px;">
                                    <div style="width:48px;height:48px;background:linear-gradient(135deg, #4DB6AC 0%, #26A69A 100%);border-radius:12px;display:flex;align-items:center;justify-content:center;">
                                        <span class="material-icons" style="color:white;font-size:24px;">groups</span>
                                    </div>
                                    <div style="flex:1;">
                                        <div style="font-size:15px;font-weight:500;">日本旅行群</div>
                                        <div style="font-size:12px;color:var(--on-surface-variant);">群组账本 · 5位成员</div>
                                    </div>
                                    <span class="material-icons" style="color:var(--on-surface-variant);">chevron_right</span>
                                </div>
                            </div>
                        </div>

                        <!-- 底部按钮 -->
                        <div style="position:absolute;bottom:16px;left:16px;right:16px;">
                            <button class="btn btn-primary" style="width:100%;min-height:48px;display:flex;align-items:center;justify-content:center;gap:8px;">
                                <span class="material-icons">add</span>
                                创建新账本
                            </button>
                        </div>
                    </div>
                </div>
            </div>

            <!-- 15.02 创建账本 -->
            <div class="phone-wrapper">
                <div class="phone-label">15.02 创建账本</div>
                <div class="phone-frame">
                    <div class="status-bar">
                        <span class="time">9:41</span>
                        <div class="icons">
                            <span class="material-icons">signal_cellular_alt</span>
                            <span class="material-icons">wifi</span>
                            <span class="material-icons">battery_full</span>
                        </div>
                    </div>
                    <div class="screen">
                        <!-- 页面头部 -->
                        <div class="page-header">
                            <div class="back-btn"><span class="material-icons">close</span></div>
                            <div class="page-header-title">创建账本</div>
                            <span style="width:24px;"></span>
                        </div>

                        <!-- 账本类型选择 -->
                        <div style="padding:16px;">
                            <div style="font-size:14px;font-weight:500;margin-bottom:12px;">选择账本类型</div>
                            <div style="display:grid;grid-template-columns:repeat(2,1fr);gap:12px;">
                                <div class="card" style="padding:16px;text-align:center;border:2px solid var(--primary);">
                                    <div style="width:48px;height:48px;margin:0 auto 8px;background:#E3F2FD;border-radius:12px;display:flex;align-items:center;justify-content:center;">
                                        <span class="material-icons" style="color:#6495ED;font-size:24px;">family_restroom</span>
                                    </div>
                                    <div style="font-size:14px;font-weight:500;">家庭账本</div>
                                    <div style="font-size:11px;color:var(--on-surface-variant);">适合家庭成员共同记账</div>
                                </div>
                                <div class="card" style="padding:16px;text-align:center;">
                                    <div style="width:48px;height:48px;margin:0 auto 8px;background:#FCE4EC;border-radius:12px;display:flex;align-items:center;justify-content:center;">
                                        <span class="material-icons" style="color:#EC407A;font-size:24px;">favorite</span>
                                    </div>
                                    <div style="font-size:14px;font-weight:500;">情侣账本</div>
                                    <div style="font-size:11px;color:var(--on-surface-variant);">两人共同管理财务</div>
                                </div>
                                <div class="card" style="padding:16px;text-align:center;">
                                    <div style="width:48px;height:48px;margin:0 auto 8px;background:#E0F2F1;border-radius:12px;display:flex;align-items:center;justify-content:center;">
                                        <span class="material-icons" style="color:#26A69A;font-size:24px;">groups</span>
                                    </div>
                                    <div style="font-size:14px;font-weight:500;">群组账本</div>
                                    <div style="font-size:11px;color:var(--on-surface-variant);">多人AA制、活动记账</div>
                                </div>
                                <div class="card" style="padding:16px;text-align:center;">
                                    <div style="width:48px;height:48px;margin:0 auto 8px;background:#FFF3E0;border-radius:12px;display:flex;align-items:center;justify-content:center;">
                                        <span class="material-icons" style="color:#FFB74D;font-size:24px;">folder_special</span>
                                    </div>
                                    <div style="font-size:14px;font-weight:500;">项目账本</div>
                                    <div style="font-size:11px;color:var(--on-surface-variant);">专项支出追踪</div>
                                </div>
                            </div>
                        </div>

                        <!-- 账本信息 -->
                        <div style="padding:0 16px;">
                            <div style="font-size:14px;font-weight:500;margin-bottom:12px;">账本信息</div>
                            <div class="card" style="padding:16px;">
                                <div style="margin-bottom:16px;">
                                    <div style="font-size:12px;color:var(--on-surface-variant);margin-bottom:6px;">账本名称</div>
                                    <input type="text" placeholder="给账本取个名字" style="width:100%;padding:12px;border:1px solid var(--outline-variant);border-radius:8px;font-size:14px;">
                                </div>
                                <div style="margin-bottom:16px;">
                                    <div style="font-size:12px;color:var(--on-surface-variant);margin-bottom:6px;">账本图标</div>
                                    <div style="display:flex;gap:12px;">
                                        <div style="width:44px;height:44px;background:#E3F2FD;border-radius:10px;display:flex;align-items:center;justify-content:center;border:2px solid var(--primary);">
                                            <span class="material-icons" style="color:#6495ED;">family_restroom</span>
                                        </div>
                                        <div style="width:44px;height:44px;background:var(--surface-variant);border-radius:10px;display:flex;align-items:center;justify-content:center;">
                                            <span class="material-icons" style="color:var(--on-surface-variant);">home</span>
                                        </div>
                                        <div style="width:44px;height:44px;background:var(--surface-variant);border-radius:10px;display:flex;align-items:center;justify-content:center;">
                                            <span class="material-icons" style="color:var(--on-surface-variant);">cottage</span>
                                        </div>
                                        <div style="width:44px;height:44px;background:var(--surface-variant);border-radius:10px;display:flex;align-items:center;justify-content:center;">
                                            <span class="material-icons" style="color:var(--on-surface-variant);">more_horiz</span>
                                        </div>
                                    </div>
                                </div>
                                <div>
                                    <div style="font-size:12px;color:var(--on-surface-variant);margin-bottom:6px;">账本描述（可选）</div>
                                    <textarea placeholder="添加账本描述..." style="width:100%;padding:12px;border:1px solid var(--outline-variant);border-radius:8px;font-size:14px;height:60px;resize:none;"></textarea>
                                </div>
                            </div>
                        </div>

                        <!-- 底部按钮 -->
                        <div style="position:absolute;bottom:16px;left:16px;right:16px;">
                            <button class="btn btn-primary" style="width:100%;min-height:48px;">创建账本</button>
                        </div>
                    </div>
                </div>
            </div>

            <!-- 15.03 成员管理 -->
            <div class="phone-wrapper">
                <div class="phone-label">15.03 成员管理</div>
                <div class="phone-frame">
                    <div class="status-bar">
                        <span class="time">9:41</span>
                        <div class="icons">
                            <span class="material-icons">signal_cellular_alt</span>
                            <span class="material-icons">wifi</span>
                            <span class="material-icons">battery_full</span>
                        </div>
                    </div>
                    <div class="screen">
                        <!-- 页面头部 -->
                        <div class="page-header">
                            <div class="back-btn"><span class="material-icons">arrow_back</span></div>
                            <div class="page-header-title">成员管理</div>
                            <span class="material-icons">person_add</span>
                        </div>

                        <!-- 账本信息 -->
                        <div style="margin:16px;padding:16px;background:linear-gradient(135deg, #FFB74D 0%, #FFA726 100%);border-radius:16px;color:white;">
                            <div style="display:flex;align-items:center;gap:12px;">
                                <div style="width:48px;height:48px;background:rgba(255,255,255,0.2);border-radius:12px;display:flex;align-items:center;justify-content:center;">
                                    <span class="material-icons" style="font-size:24px;">family_restroom</span>
                                </div>
                                <div>
                                    <div style="font-size:16px;font-weight:600;">温馨小家</div>
                                    <div style="font-size:12px;opacity:0.9;">家庭账本 · 3位成员</div>
                                </div>
                            </div>
                        </div>

                        <!-- 成员列表 -->
                        <div style="padding:0 16px;">
                            <div style="font-size:13px;font-weight:500;color:var(--on-surface-variant);margin-bottom:12px;">成员列表</div>

                            <!-- 所有者 -->
                            <div class="card" style="padding:14px 16px;margin-bottom:8px;">
                                <div style="display:flex;align-items:center;gap:12px;">
                                    <div style="width:44px;height:44px;background:linear-gradient(135deg, #6495ED 0%, #4169E1 100%);border-radius:50%;display:flex;align-items:center;justify-content:center;color:white;font-weight:600;">我</div>
                                    <div style="flex:1;">
                                        <div style="display:flex;align-items:center;gap:6px;">
                                            <span style="font-size:15px;font-weight:500;">张三</span>
                                            <span style="padding:2px 6px;background:#E3F2FD;border-radius:4px;font-size:10px;color:#6495ED;">所有者</span>
                                        </div>
                                        <div style="font-size:12px;color:var(--on-surface-variant);">可查看、编辑、管理成员</div>
                                    </div>
                                    <span class="material-icons" style="color:var(--on-surface-variant);">more_vert</span>
                                </div>
                            </div>

                            <!-- 管理员 -->
                            <div class="card" style="padding:14px 16px;margin-bottom:8px;">
                                <div style="display:flex;align-items:center;gap:12px;">
                                    <div style="width:44px;height:44px;background:#FCE4EC;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:20px;">👩</div>
                                    <div style="flex:1;">
                                        <div style="display:flex;align-items:center;gap:6px;">
                                            <span style="font-size:15px;font-weight:500;">小美</span>
                                            <span style="padding:2px 6px;background:#E8F5E9;border-radius:4px;font-size:10px;color:#66BB6A;">管理员</span>
                                        </div>
                                        <div style="font-size:12px;color:var(--on-surface-variant);">可查看、编辑所有记录</div>
                                    </div>
                                    <span class="material-icons" style="color:var(--on-surface-variant);">more_vert</span>
                                </div>
                            </div>

                            <!-- 普通成员 -->
                            <div class="card" style="padding:14px 16px;margin-bottom:8px;">
                                <div style="display:flex;align-items:center;gap:12px;">
                                    <div style="width:44px;height:44px;background:#FFF3E0;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:20px;">👶</div>
                                    <div style="flex:1;">
                                        <div style="display:flex;align-items:center;gap:6px;">
                                            <span style="font-size:15px;font-weight:500;">小宝</span>
                                            <span style="padding:2px 6px;background:var(--surface-variant);border-radius:4px;font-size:10px;color:var(--on-surface-variant);">成员</span>
                                        </div>
                                        <div style="font-size:12px;color:var(--on-surface-variant);">可查看、添加自己的记录</div>
                                    </div>
                                    <span class="material-icons" style="color:var(--on-surface-variant);">more_vert</span>
                                </div>
                            </div>
                        </div>

                        <!-- 待处理邀请 -->
                        <div style="padding:16px;">
                            <div style="font-size:13px;font-weight:500;color:var(--on-surface-variant);margin-bottom:12px;">待接受邀请</div>
                            <div class="card" style="padding:14px 16px;background:#FFF8E1;">
                                <div style="display:flex;align-items:center;gap:12px;">
                                    <div style="width:44px;height:44px;background:#FFE082;border-radius:50%;display:flex;align-items:center;justify-content:center;">
                                        <span class="material-icons" style="color:#F57C00;">schedule</span>
                                    </div>
                                    <div style="flex:1;">
                                        <div style="font-size:14px;font-weight:500;">139****8888</div>
                                        <div style="font-size:12px;color:var(--on-surface-variant);">邀请中 · 还剩6天有效期</div>
                                    </div>
                                    <button class="btn btn-outline" style="min-height:32px;padding:0 12px;font-size:12px;">取消</button>
                                </div>
                            </div>
                        </div>

                        <!-- 邀请按钮 -->
                        <div style="position:absolute;bottom:16px;left:16px;right:16px;">
                            <button class="btn btn-primary" style="width:100%;min-height:48px;display:flex;align-items:center;justify-content:center;gap:8px;">
                                <span class="material-icons">person_add</span>
                                邀请新成员
                            </button>
                        </div>
                    </div>
                </div>
            </div>

            <!-- 15.04 邀请成员 -->
            <div class="phone-wrapper">
                <div class="phone-label">15.04 邀请成员</div>
                <div class="phone-frame">
                    <div class="status-bar">
                        <span class="time">9:41</span>
                        <div class="icons">
                            <span class="material-icons">signal_cellular_alt</span>
                            <span class="material-icons">wifi</span>
                            <span class="material-icons">battery_full</span>
                        </div>
                    </div>
                    <div class="screen">
                        <!-- 页面头部 -->
                        <div class="page-header">
                            <div class="back-btn"><span class="material-icons">close</span></div>
                            <div class="page-header-title">邀请成员</div>
                            <span style="width:24px;"></span>
                        </div>

                        <!-- 邀请二维码 -->
                        <div style="margin:16px;padding:24px;background:white;border-radius:16px;text-align:center;box-shadow:0 2px 8px rgba(0,0,0,0.08);">
                            <div style="font-size:15px;font-weight:500;margin-bottom:16px;">扫码加入「温馨小家」</div>
                            <div style="width:180px;height:180px;margin:0 auto 16px;background:linear-gradient(45deg, #000 25%, transparent 25%, transparent 75%, #000 75%), linear-gradient(45deg, #000 25%, transparent 25%, transparent 75%, #000 75%), linear-gradient(to right, #fff, #fff);background-size:8px 8px, 8px 8px, 4px 4px;background-position:0 0, 4px 4px, 0 0;border:4px solid #6495ED;border-radius:12px;display:flex;align-items:center;justify-content:center;">
                                <div style="padding:12px;background:white;border-radius:8px;">
                                    <span class="material-icons" style="font-size:40px;color:#6495ED;">qr_code_2</span>
                                </div>
                            </div>
                            <div style="font-size:12px;color:var(--on-surface-variant);">邀请码 7天内有效</div>
                        </div>

                        <!-- 其他邀请方式 -->
                        <div style="padding:0 16px;">
                            <div style="font-size:13px;font-weight:500;color:var(--on-surface-variant);margin-bottom:12px;">其他邀请方式</div>

                            <div class="card" style="padding:14px 16px;margin-bottom:8px;">
                                <div style="display:flex;align-items:center;gap:12px;">
                                    <div style="width:40px;height:40px;background:#E8F5E9;border-radius:10px;display:flex;align-items:center;justify-content:center;">
                                        <span class="material-icons" style="color:#66BB6A;">link</span>
                                    </div>
                                    <div style="flex:1;">
                                        <div style="font-size:14px;font-weight:500;">复制邀请链接</div>
                                        <div style="font-size:12px;color:var(--on-surface-variant);">分享链接给好友</div>
                                    </div>
                                    <span class="material-icons" style="color:var(--on-surface-variant);">chevron_right</span>
                                </div>
                            </div>

                            <div class="card" style="padding:14px 16px;margin-bottom:8px;">
                                <div style="display:flex;align-items:center;gap:12px;">
                                    <div style="width:40px;height:40px;background:#E3F2FD;border-radius:10px;display:flex;align-items:center;justify-content:center;">
                                        <span class="material-icons" style="color:#6495ED;">contacts</span>
                                    </div>
                                    <div style="flex:1;">
                                        <div style="font-size:14px;font-weight:500;">从通讯录邀请</div>
                                        <div style="font-size:12px;color:var(--on-surface-variant);">选择联系人发送邀请</div>
                                    </div>
                                    <span class="material-icons" style="color:var(--on-surface-variant);">chevron_right</span>
                                </div>
                            </div>

                            <div class="card" style="padding:14px 16px;">
                                <div style="display:flex;align-items:center;gap:12px;">
                                    <div style="width:40px;height:40px;background:#FCE4EC;border-radius:10px;display:flex;align-items:center;justify-content:center;">
                                        <span class="material-icons" style="color:#EC407A;">share</span>
                                    </div>
                                    <div style="flex:1;">
                                        <div style="font-size:14px;font-weight:500;">分享到微信</div>
                                        <div style="font-size:12px;color:var(--on-surface-variant);">发送给微信好友或群</div>
                                    </div>
                                    <span class="material-icons" style="color:var(--on-surface-variant);">chevron_right</span>
                                </div>
                            </div>
                        </div>

                        <!-- 权限设置 -->
                        <div style="padding:16px;">
                            <div style="font-size:13px;font-weight:500;color:var(--on-surface-variant);margin-bottom:12px;">邀请权限设置</div>
                            <div class="card" style="padding:14px 16px;">
                                <div style="display:flex;align-items:center;justify-content:space-between;">
                                    <div>
                                        <div style="font-size:14px;font-weight:500;">默认成员角色</div>
                                        <div style="font-size:12px;color:var(--on-surface-variant);">新成员加入后的默认权限</div>
                                    </div>
                                    <div style="display:flex;align-items:center;gap:4px;color:var(--primary);">
                                        <span style="font-size:13px;">成员</span>
                                        <span class="material-icons" style="font-size:18px;">expand_more</span>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- 15.05 权限设置 -->
            <div class="phone-wrapper">
                <div class="phone-label">15.05 权限设置</div>
                <div class="phone-frame">
                    <div class="status-bar">
                        <span class="time">9:41</span>
                        <div class="icons">
                            <span class="material-icons">signal_cellular_alt</span>
                            <span class="material-icons">wifi</span>
                            <span class="material-icons">battery_full</span>
                        </div>
                    </div>
                    <div class="screen">
                        <!-- 页面头部 -->
                        <div class="page-header">
                            <div class="back-btn"><span class="material-icons">arrow_back</span></div>
                            <div class="page-header-title">权限设置</div>
                            <span style="width:24px;"></span>
                        </div>

                        <!-- 成员信息 -->
                        <div style="margin:16px;padding:16px;background:var(--surface-variant);border-radius:12px;">
                            <div style="display:flex;align-items:center;gap:12px;">
                                <div style="width:48px;height:48px;background:#FCE4EC;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:24px;">👩</div>
                                <div>
                                    <div style="font-size:16px;font-weight:500;">小美</div>
                                    <div style="font-size:12px;color:var(--on-surface-variant);">当前角色：管理员</div>
                                </div>
                            </div>
                        </div>

                        <!-- 角色选择 -->
                        <div style="padding:0 16px 16px;">
                            <div style="font-size:13px;font-weight:500;color:var(--on-surface-variant);margin-bottom:12px;">选择角色</div>

                            <div class="card" style="padding:14px 16px;margin-bottom:8px;border:2px solid var(--primary);">
                                <div style="display:flex;align-items:center;gap:12px;">
                                    <div style="width:40px;height:40px;background:#E8F5E9;border-radius:10px;display:flex;align-items:center;justify-content:center;">
                                        <span class="material-icons" style="color:#66BB6A;">admin_panel_settings</span>
                                    </div>
                                    <div style="flex:1;">
                                        <div style="font-size:14px;font-weight:500;">管理员</div>
                                        <div style="font-size:11px;color:var(--on-surface-variant);">可查看、编辑所有记录，管理成员</div>
                                    </div>
                                    <span class="material-icons" style="color:var(--primary);">check_circle</span>
                                </div>
                            </div>

                            <div class="card" style="padding:14px 16px;margin-bottom:8px;">
                                <div style="display:flex;align-items:center;gap:12px;">
                                    <div style="width:40px;height:40px;background:#E3F2FD;border-radius:10px;display:flex;align-items:center;justify-content:center;">
                                        <span class="material-icons" style="color:#6495ED;">person</span>
                                    </div>
                                    <div style="flex:1;">
                                        <div style="font-size:14px;font-weight:500;">成员</div>
                                        <div style="font-size:11px;color:var(--on-surface-variant);">可查看公开记录，管理自己的记录</div>
                                    </div>
                                </div>
                            </div>

                            <div class="card" style="padding:14px 16px;">
                                <div style="display:flex;align-items:center;gap:12px;">
                                    <div style="width:40px;height:40px;background:var(--surface-variant);border-radius:10px;display:flex;align-items:center;justify-content:center;">
                                        <span class="material-icons" style="color:var(--on-surface-variant);">visibility</span>
                                    </div>
                                    <div style="flex:1;">
                                        <div style="font-size:14px;font-weight:500;">只读成员</div>
                                        <div style="font-size:11px;color:var(--on-surface-variant);">仅可查看公开记录</div>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <!-- 详细权限 -->
                        <div style="padding:0 16px;">
                            <div style="font-size:13px;font-weight:500;color:var(--on-surface-variant);margin-bottom:12px;">详细权限</div>
                            <div class="card" style="padding:0;">
                                <div class="list-item" style="padding:14px 16px;border-bottom:1px solid var(--outline-variant);">
                                    <div style="flex:1;">
                                        <div style="font-size:14px;">查看所有记录</div>
                                    </div>
                                    <div class="toggle active"></div>
                                </div>
                                <div class="list-item" style="padding:14px 16px;border-bottom:1px solid var(--outline-variant);">
                                    <div style="flex:1;">
                                        <div style="font-size:14px;">编辑他人记录</div>
                                    </div>
                                    <div class="toggle active"></div>
                                </div>
                                <div class="list-item" style="padding:14px 16px;border-bottom:1px solid var(--outline-variant);">
                                    <div style="flex:1;">
                                        <div style="font-size:14px;">删除记录</div>
                                    </div>
                                    <div class="toggle active"></div>
                                </div>
                                <div class="list-item" style="padding:14px 16px;">
                                    <div style="flex:1;">
                                        <div style="font-size:14px;">邀请新成员</div>
                                    </div>
                                    <div class="toggle active"></div>
                                </div>
                            </div>
                        </div>

                        <!-- 保存按钮 -->
                        <div style="position:absolute;bottom:16px;left:16px;right:16px;">
                            <button class="btn btn-primary" style="width:100%;min-height:48px;">保存更改</button>
                        </div>
                    </div>
                </div>
            </div>

            <!-- 15.06 家庭预算 -->
            <div class="phone-wrapper">
                <div class="phone-label">15.06 家庭预算</div>
                <div class="phone-frame">
                    <div class="status-bar">
                        <span class="time">9:41</span>
                        <div class="icons">
                            <span class="material-icons">signal_cellular_alt</span>
                            <span class="material-icons">wifi</span>
                            <span class="material-icons">battery_full</span>
                        </div>
                    </div>
                    <div class="screen">
                        <!-- 页面头部 -->
                        <div class="page-header">
                            <div class="back-btn"><span class="material-icons">arrow_back</span></div>
                            <div class="page-header-title">家庭预算</div>
                            <span class="material-icons">settings</span>
                        </div>

                        <!-- 预算概览 -->
                        <div style="margin:16px;padding:20px;background:linear-gradient(135deg, #FFB74D 0%, #FFA726 100%);border-radius:16px;color:white;">
                            <div style="font-size:13px;opacity:0.9;margin-bottom:4px;">本月家庭预算</div>
                            <div style="font-size:32px;font-weight:700;margin-bottom:12px;">¥15,000</div>
                            <div style="height:8px;background:rgba(255,255,255,0.3);border-radius:4px;overflow:hidden;margin-bottom:8px;">
                                <div style="width:62%;height:100%;background:white;border-radius:4px;"></div>
                            </div>
                            <div style="display:flex;justify-content:space-between;font-size:12px;">
                                <span>已用 ¥9,280 (62%)</span>
                                <span>剩余 ¥5,720</span>
                            </div>
                        </div>

                        <!-- 成员消费排行 -->
                        <div style="padding:0 16px 16px;">
                            <div style="font-size:14px;font-weight:500;margin-bottom:12px;">成员消费</div>
                            <div class="card" style="padding:0;">
                                <div class="list-item" style="padding:14px 16px;border-bottom:1px solid var(--outline-variant);">
                                    <div style="width:36px;height:36px;background:#E3F2FD;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:12px;font-weight:500;color:#6495ED;">我</div>
                                    <div class="list-item-content" style="margin-left:12px;">
                                        <div class="list-item-title">张三</div>
                                        <div style="height:4px;background:var(--surface-variant);border-radius:2px;margin-top:6px;width:120px;">
                                            <div style="width:75%;height:100%;background:#6495ED;border-radius:2px;"></div>
                                        </div>
                                    </div>
                                    <div style="text-align:right;">
                                        <div style="font-size:15px;font-weight:600;">¥4,520</div>
                                        <div style="font-size:11px;color:var(--on-surface-variant);">49%</div>
                                    </div>
                                </div>
                                <div class="list-item" style="padding:14px 16px;border-bottom:1px solid var(--outline-variant);">
                                    <div style="width:36px;height:36px;background:#FCE4EC;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:16px;">👩</div>
                                    <div class="list-item-content" style="margin-left:12px;">
                                        <div class="list-item-title">小美</div>
                                        <div style="height:4px;background:var(--surface-variant);border-radius:2px;margin-top:6px;width:120px;">
                                            <div style="width:40%;height:100%;background:#EC407A;border-radius:2px;"></div>
                                        </div>
                                    </div>
                                    <div style="text-align:right;">
                                        <div style="font-size:15px;font-weight:600;">¥3,680</div>
                                        <div style="font-size:11px;color:var(--on-surface-variant);">40%</div>
                                    </div>
                                </div>
                                <div class="list-item" style="padding:14px 16px;">
                                    <div style="width:36px;height:36px;background:#FFF3E0;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:16px;">👶</div>
                                    <div class="list-item-content" style="margin-left:12px;">
                                        <div class="list-item-title">小宝</div>
                                        <div style="height:4px;background:var(--surface-variant);border-radius:2px;margin-top:6px;width:120px;">
                                            <div style="width:18%;height:100%;background:#FFB74D;border-radius:2px;"></div>
                                        </div>
                                    </div>
                                    <div style="text-align:right;">
                                        <div style="font-size:15px;font-weight:600;">¥1,080</div>
                                        <div style="font-size:11px;color:var(--on-surface-variant);">11%</div>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <!-- 分类预算 -->
                        <div style="padding:0 16px;">
                            <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px;">
                                <div style="font-size:14px;font-weight:500;">分类预算</div>
                                <span style="font-size:12px;color:var(--primary);">管理预算</span>
                            </div>
                            <div style="display:flex;gap:8px;overflow-x:auto;padding-bottom:8px;">
                                <div class="card" style="min-width:120px;padding:12px;text-align:center;flex-shrink:0;">
                                    <span style="font-size:24px;">🍜</span>
                                    <div style="font-size:12px;font-weight:500;margin:6px 0 2px;">餐饮</div>
                                    <div style="font-size:11px;color:var(--on-surface-variant);">¥2,800/¥4,000</div>
                                    <div style="height:4px;background:var(--surface-variant);border-radius:2px;margin-top:6px;">
                                        <div style="width:70%;height:100%;background:#FFB74D;border-radius:2px;"></div>
                                    </div>
                                </div>
                                <div class="card" style="min-width:120px;padding:12px;text-align:center;flex-shrink:0;">
                                    <span style="font-size:24px;">🛒</span>
                                    <div style="font-size:12px;font-weight:500;margin:6px 0 2px;">日用品</div>
                                    <div style="font-size:11px;color:var(--on-surface-variant);">¥1,200/¥2,000</div>
                                    <div style="height:4px;background:var(--surface-variant);border-radius:2px;margin-top:6px;">
                                        <div style="width:60%;height:100%;background:#66BB6A;border-radius:2px;"></div>
                                    </div>
                                </div>
                                <div class="card" style="min-width:120px;padding:12px;text-align:center;flex-shrink:0;">
                                    <span style="font-size:24px;">🎓</span>
                                    <div style="font-size:12px;font-weight:500;margin:6px 0 2px;">教育</div>
                                    <div style="font-size:11px;color:var(--on-surface-variant);">¥3,500/¥3,000</div>
                                    <div style="height:4px;background:var(--surface-variant);border-radius:2px;margin-top:6px;">
                                        <div style="width:100%;height:100%;background:#E57373;border-radius:2px;"></div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- 15.07 家庭统计 -->
            <div class="phone-wrapper">
                <div class="phone-label">15.07 家庭统计</div>
                <div class="phone-frame">
                    <div class="status-bar">
                        <span class="time">9:41</span>
                        <div class="icons">
                            <span class="material-icons">signal_cellular_alt</span>
                            <span class="material-icons">wifi</span>
                            <span class="material-icons">battery_full</span>
                        </div>
                    </div>
                    <div class="screen">
                        <!-- 页面头部 -->
                        <div class="page-header">
                            <div class="back-btn"><span class="material-icons">arrow_back</span></div>
                            <div class="page-header-title">家庭统计</div>
                            <span class="material-icons">share</span>
                        </div>

                        <!-- 时间筛选 -->
                        <div style="padding:12px 16px;display:flex;gap:8px;">
                            <button class="btn btn-primary" style="min-height:32px;padding:0 16px;font-size:13px;">本月</button>
                            <button class="btn btn-outline" style="min-height:32px;padding:0 16px;font-size:13px;">上月</button>
                            <button class="btn btn-outline" style="min-height:32px;padding:0 16px;font-size:13px;">本年</button>
                            <button class="btn btn-outline" style="min-height:32px;padding:0 16px;font-size:13px;">自定义</button>
                        </div>

                        <!-- 总览卡片 -->
                        <div style="display:flex;gap:12px;padding:0 16px 16px;">
                            <div class="card" style="flex:1;padding:16px;text-align:center;">
                                <div style="font-size:12px;color:var(--on-surface-variant);margin-bottom:4px;">总支出</div>
                                <div style="font-size:20px;font-weight:700;color:#E57373;">¥9,280</div>
                            </div>
                            <div class="card" style="flex:1;padding:16px;text-align:center;">
                                <div style="font-size:12px;color:var(--on-surface-variant);margin-bottom:4px;">总收入</div>
                                <div style="font-size:20px;font-weight:700;color:#66BB6A;">¥18,500</div>
                            </div>
                            <div class="card" style="flex:1;padding:16px;text-align:center;">
                                <div style="font-size:12px;color:var(--on-surface-variant);margin-bottom:4px;">结余</div>
                                <div style="font-size:20px;font-weight:700;color:#6495ED;">¥9,220</div>
                            </div>
                        </div>

                        <!-- 支出分布图 -->
                        <div style="padding:0 16px 16px;">
                            <div style="font-size:14px;font-weight:500;margin-bottom:12px;">支出分布</div>
                            <div class="card" style="padding:16px;">
                                <div style="display:flex;align-items:center;gap:16px;">
                                    <div style="width:100px;height:100px;border-radius:50%;background:conic-gradient(#6495ED 0deg 130deg, #FFB74D 130deg 220deg, #66BB6A 220deg 280deg, #9370DB 280deg 320deg, #E57373 320deg 360deg);display:flex;align-items:center;justify-content:center;">
                                        <div style="width:60px;height:60px;background:white;border-radius:50%;"></div>
                                    </div>
                                    <div style="flex:1;display:flex;flex-direction:column;gap:6px;">
                                        <div style="display:flex;align-items:center;gap:8px;font-size:12px;">
                                            <div style="width:10px;height:10px;background:#6495ED;border-radius:2px;"></div>
                                            <span style="flex:1;">餐饮</span>
                                            <span style="font-weight:500;">36%</span>
                                        </div>
                                        <div style="display:flex;align-items:center;gap:8px;font-size:12px;">
                                            <div style="width:10px;height:10px;background:#FFB74D;border-radius:2px;"></div>
                                            <span style="flex:1;">教育</span>
                                            <span style="font-weight:500;">25%</span>
                                        </div>
                                        <div style="display:flex;align-items:center;gap:8px;font-size:12px;">
                                            <div style="width:10px;height:10px;background:#66BB6A;border-radius:2px;"></div>
                                            <span style="flex:1;">日用品</span>
                                            <span style="font-weight:500;">17%</span>
                                        </div>
                                        <div style="display:flex;align-items:center;gap:8px;font-size:12px;">
                                            <div style="width:10px;height:10px;background:#9370DB;border-radius:2px;"></div>
                                            <span style="flex:1;">交通</span>
                                            <span style="font-weight:500;">11%</span>
                                        </div>
                                        <div style="display:flex;align-items:center;gap:8px;font-size:12px;">
                                            <div style="width:10px;height:10px;background:#E57373;border-radius:2px;"></div>
                                            <span style="flex:1;">其他</span>
                                            <span style="font-weight:500;">11%</span>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <!-- 成员贡献 -->
                        <div style="padding:0 16px;">
                            <div style="font-size:14px;font-weight:500;margin-bottom:12px;">成员记账贡献</div>
                            <div class="card" style="padding:16px;">
                                <div style="display:flex;justify-content:space-around;text-align:center;">
                                    <div>
                                        <div style="width:48px;height:48px;margin:0 auto 8px;background:#E3F2FD;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:13px;font-weight:500;color:#6495ED;">我</div>
                                        <div style="font-size:13px;font-weight:500;">张三</div>
                                        <div style="font-size:20px;font-weight:700;color:#6495ED;">28笔</div>
                                    </div>
                                    <div>
                                        <div style="width:48px;height:48px;margin:0 auto 8px;background:#FCE4EC;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:20px;">👩</div>
                                        <div style="font-size:13px;font-weight:500;">小美</div>
                                        <div style="font-size:20px;font-weight:700;color:#EC407A;">15笔</div>
                                    </div>
                                    <div>
                                        <div style="width:48px;height:48px;margin:0 auto 8px;background:#FFF3E0;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:20px;">👶</div>
                                        <div style="font-size:13px;font-weight:500;">小宝</div>
                                        <div style="font-size:20px;font-weight:700;color:#FFB74D;">3笔</div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- 15.08 账本设置 -->
            <div class="phone-wrapper">
                <div class="phone-label">15.08 账本设置</div>
                <div class="phone-frame">
                    <div class="status-bar">
                        <span class="time">9:41</span>
                        <div class="icons">
                            <span class="material-icons">signal_cellular_alt</span>
                            <span class="material-icons">wifi</span>
                            <span class="material-icons">battery_full</span>
                        </div>
                    </div>
                    <div class="screen">
                        <!-- 页面头部 -->
                        <div class="page-header">
                            <div class="back-btn"><span class="material-icons">arrow_back</span></div>
                            <div class="page-header-title">账本设置</div>
                            <span style="width:24px;"></span>
                        </div>

                        <!-- 账本信息 -->
                        <div style="padding:16px;">
                            <div class="card" style="padding:0;">
                                <div class="list-item" style="padding:14px 16px;border-bottom:1px solid var(--outline-variant);">
                                    <div style="flex:1;">
                                        <div style="font-size:14px;">账本名称</div>
                                    </div>
                                    <div style="display:flex;align-items:center;gap:4px;color:var(--on-surface-variant);">
                                        <span style="font-size:14px;">温馨小家</span>
                                        <span class="material-icons" style="font-size:18px;">chevron_right</span>
                                    </div>
                                </div>
                                <div class="list-item" style="padding:14px 16px;border-bottom:1px solid var(--outline-variant);">
                                    <div style="flex:1;">
                                        <div style="font-size:14px;">账本图标</div>
                                    </div>
                                    <div style="display:flex;align-items:center;gap:4px;">
                                        <span class="material-icons" style="color:#FFB74D;">family_restroom</span>
                                        <span class="material-icons" style="font-size:18px;color:var(--on-surface-variant);">chevron_right</span>
                                    </div>
                                </div>
                                <div class="list-item" style="padding:14px 16px;">
                                    <div style="flex:1;">
                                        <div style="font-size:14px;">账本类型</div>
                                    </div>
                                    <span style="font-size:14px;color:var(--on-surface-variant);">家庭账本</span>
                                </div>
                            </div>
                        </div>

                        <!-- 隐私设置 -->
                        <div style="padding:0 16px 16px;">
                            <div style="font-size:13px;font-weight:500;color:var(--on-surface-variant);margin-bottom:12px;">隐私设置</div>
                            <div class="card" style="padding:0;">
                                <div class="list-item" style="padding:14px 16px;border-bottom:1px solid var(--outline-variant);">
                                    <div style="flex:1;">
                                        <div style="font-size:14px;">默认记录可见性</div>
                                        <div style="font-size:12px;color:var(--on-surface-variant);">新记录默认对谁可见</div>
                                    </div>
                                    <div style="display:flex;align-items:center;gap:4px;color:var(--primary);">
                                        <span style="font-size:13px;">所有成员</span>
                                        <span class="material-icons" style="font-size:18px;">expand_more</span>
                                    </div>
                                </div>
                                <div class="list-item" style="padding:14px 16px;">
                                    <div style="flex:1;">
                                        <div style="font-size:14px;">隐藏金额</div>
                                        <div style="font-size:12px;color:var(--on-surface-variant);">普通成员看不到具体金额</div>
                                    </div>
                                    <div class="toggle"></div>
                                </div>
                            </div>
                        </div>

                        <!-- 通知设置 -->
                        <div style="padding:0 16px 16px;">
                            <div style="font-size:13px;font-weight:500;color:var(--on-surface-variant);margin-bottom:12px;">通知设置</div>
                            <div class="card" style="padding:0;">
                                <div class="list-item" style="padding:14px 16px;border-bottom:1px solid var(--outline-variant);">
                                    <div style="flex:1;">
                                        <div style="font-size:14px;">成员记账通知</div>
                                    </div>
                                    <div class="toggle active"></div>
                                </div>
                                <div class="list-item" style="padding:14px 16px;">
                                    <div style="flex:1;">
                                        <div style="font-size:14px;">预算超支提醒</div>
                                    </div>
                                    <div class="toggle active"></div>
                                </div>
                            </div>
                        </div>

                        <!-- 危险操作 -->
                        <div style="padding:0 16px;">
                            <div style="font-size:13px;font-weight:500;color:var(--on-surface-variant);margin-bottom:12px;">危险操作</div>
                            <div class="card" style="padding:0;">
                                <div class="list-item" style="padding:14px 16px;border-bottom:1px solid var(--outline-variant);">
                                    <div style="flex:1;">
                                        <div style="font-size:14px;color:#E57373;">退出账本</div>
                                    </div>
                                    <span class="material-icons" style="color:var(--on-surface-variant);font-size:18px;">chevron_right</span>
                                </div>
                                <div class="list-item" style="padding:14px 16px;">
                                    <div style="flex:1;">
                                        <div style="font-size:14px;color:#E57373;">删除账本</div>
                                        <div style="font-size:12px;color:var(--on-surface-variant);">仅所有者可操作</div>
                                    </div>
                                    <span class="material-icons" style="color:var(--on-surface-variant);font-size:18px;">chevron_right</span>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

        </div>
    </div>

'''

# SECTION 16: NPS与用户增长 (8个页面)
section_16 = '''
    <!-- ==================== SECTION 16: NPS与用户增长（8个页面）==================== -->
    <div id="nps-growth" class="section">
        <h2>SECTION 16: NPS与用户增长</h2>
        <div class="section-grid">

            <!-- 16.01 NPS调查弹窗 -->
            <div class="phone-wrapper">
                <div class="phone-label">16.01 NPS调查弹窗</div>
                <div class="phone-frame">
                    <div class="status-bar">
                        <span class="time">9:41</span>
                        <div class="icons">
                            <span class="material-icons">signal_cellular_alt</span>
                            <span class="material-icons">wifi</span>
                            <span class="material-icons">battery_full</span>
                        </div>
                    </div>
                    <div class="screen" style="display:flex;flex-direction:column;">
                        <!-- 半透明背景 -->
                        <div style="flex:1;background:rgba(0,0,0,0.5);display:flex;align-items:center;justify-content:center;padding:24px;">
                            <!-- 调查卡片 -->
                            <div style="width:100%;background:white;border-radius:20px;padding:24px;text-align:center;">
                                <!-- 表情图标 -->
                                <div style="font-size:48px;margin-bottom:16px;">😊</div>

                                <div style="font-size:18px;font-weight:600;margin-bottom:8px;">您使用的体验如何？</div>
                                <div style="font-size:13px;color:var(--on-surface-variant);margin-bottom:20px;">您的反馈对我们非常重要</div>

                                <!-- NPS评分 -->
                                <div style="margin-bottom:16px;">
                                    <div style="display:flex;justify-content:space-between;margin-bottom:8px;">
                                        <span style="font-size:11px;color:var(--on-surface-variant);">完全不推荐</span>
                                        <span style="font-size:11px;color:var(--on-surface-variant);">强烈推荐</span>
                                    </div>
                                    <div style="display:flex;gap:4px;">
                                        <div style="flex:1;height:40px;background:#FFEBEE;border-radius:6px;display:flex;align-items:center;justify-content:center;font-size:14px;font-weight:500;color:#E57373;">0</div>
                                        <div style="flex:1;height:40px;background:#FFEBEE;border-radius:6px;display:flex;align-items:center;justify-content:center;font-size:14px;font-weight:500;color:#E57373;">1</div>
                                        <div style="flex:1;height:40px;background:#FFEBEE;border-radius:6px;display:flex;align-items:center;justify-content:center;font-size:14px;font-weight:500;color:#E57373;">2</div>
                                        <div style="flex:1;height:40px;background:#FFEBEE;border-radius:6px;display:flex;align-items:center;justify-content:center;font-size:14px;font-weight:500;color:#E57373;">3</div>
                                        <div style="flex:1;height:40px;background:#FFEBEE;border-radius:6px;display:flex;align-items:center;justify-content:center;font-size:14px;font-weight:500;color:#E57373;">4</div>
                                        <div style="flex:1;height:40px;background:#FFEBEE;border-radius:6px;display:flex;align-items:center;justify-content:center;font-size:14px;font-weight:500;color:#E57373;">5</div>
                                        <div style="flex:1;height:40px;background:#FFF3E0;border-radius:6px;display:flex;align-items:center;justify-content:center;font-size:14px;font-weight:500;color:#FFB74D;">6</div>
                                        <div style="flex:1;height:40px;background:#FFF3E0;border-radius:6px;display:flex;align-items:center;justify-content:center;font-size:14px;font-weight:500;color:#FFB74D;">7</div>
                                        <div style="flex:1;height:40px;background:#E8F5E9;border-radius:6px;display:flex;align-items:center;justify-content:center;font-size:14px;font-weight:500;color:#66BB6A;">8</div>
                                        <div style="flex:1;height:40px;background:linear-gradient(135deg, #6495ED 0%, #4169E1 100%);border-radius:6px;display:flex;align-items:center;justify-content:center;font-size:14px;font-weight:600;color:white;">9</div>
                                        <div style="flex:1;height:40px;background:#E8F5E9;border-radius:6px;display:flex;align-items:center;justify-content:center;font-size:14px;font-weight:500;color:#66BB6A;">10</div>
                                    </div>
                                </div>

                                <!-- 提交按钮 -->
                                <button class="btn btn-primary" style="width:100%;min-height:48px;margin-bottom:12px;">提交评分</button>
                                <button class="btn btn-text" style="width:100%;min-height:40px;color:var(--on-surface-variant);">以后再说</button>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- 16.02 惊喜时刻庆祝 -->
            <div class="phone-wrapper">
                <div class="phone-label">16.02 惊喜时刻庆祝</div>
                <div class="phone-frame">
                    <div class="status-bar">
                        <span class="time">9:41</span>
                        <div class="icons">
                            <span class="material-icons">signal_cellular_alt</span>
                            <span class="material-icons">wifi</span>
                            <span class="material-icons">battery_full</span>
                        </div>
                    </div>
                    <div class="screen" style="display:flex;flex-direction:column;">
                        <!-- 全屏庆祝 -->
                        <div style="flex:1;background:linear-gradient(135deg, #6495ED 0%, #9370DB 100%);display:flex;flex-direction:column;align-items:center;justify-content:center;padding:24px;color:white;text-align:center;">
                            <!-- 彩带效果 -->
                            <div style="position:absolute;top:0;left:0;right:0;height:100px;background:url('data:image/svg+xml,<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 100 20\"><circle cx=\"10\" cy=\"10\" r=\"3\" fill=\"%23FFD700\"/><circle cx=\"30\" cy=\"5\" r=\"2\" fill=\"%23FF69B4\"/><circle cx=\"50\" cy=\"15\" r=\"4\" fill=\"%2300CED1\"/><circle cx=\"70\" cy=\"8\" r=\"2\" fill=\"%23FF6347\"/><circle cx=\"90\" cy=\"12\" r=\"3\" fill=\"%2398FB98\"/></svg>');opacity:0.6;"></div>

                            <!-- 成就图标 -->
                            <div style="width:100px;height:100px;background:rgba(255,255,255,0.2);border-radius:50%;display:flex;align-items:center;justify-content:center;margin-bottom:24px;">
                                <span style="font-size:56px;">🎉</span>
                            </div>

                            <div style="font-size:28px;font-weight:700;margin-bottom:8px;">连续记账30天！</div>
                            <div style="font-size:15px;opacity:0.9;margin-bottom:32px;">你已经养成了良好的记账习惯<br/>这份坚持值得称赞！</div>

                            <!-- 成就徽章 -->
                            <div style="background:rgba(255,255,255,0.15);border-radius:16px;padding:16px 24px;margin-bottom:32px;">
                                <div style="font-size:12px;opacity:0.8;margin-bottom:8px;">获得成就徽章</div>
                                <div style="display:flex;align-items:center;gap:12px;">
                                    <div style="width:48px;height:48px;background:linear-gradient(135deg, #FFD700 0%, #FFA500 100%);border-radius:50%;display:flex;align-items:center;justify-content:center;">
                                        <span class="material-icons" style="font-size:28px;color:white;">military_tech</span>
                                    </div>
                                    <div style="text-align:left;">
                                        <div style="font-size:16px;font-weight:600;">月度记账达人</div>
                                        <div style="font-size:12px;opacity:0.8;">连续30天记账</div>
                                    </div>
                                </div>
                            </div>

                            <!-- 操作按钮 -->
                            <button class="btn" style="width:100%;min-height:48px;background:white;color:#6495ED;font-weight:600;margin-bottom:12px;">
                                <span class="material-icons" style="font-size:18px;margin-right:8px;">share</span>
                                分享成就
                            </button>
                            <button class="btn btn-text" style="width:100%;min-height:40px;color:rgba(255,255,255,0.8);">继续使用</button>
                        </div>
                    </div>
                </div>
            </div>

            <!-- 16.03 分享卡片生成 -->
            <div class="phone-wrapper">
                <div class="phone-label">16.03 分享卡片生成</div>
                <div class="phone-frame">
                    <div class="status-bar">
                        <span class="time">9:41</span>
                        <div class="icons">
                            <span class="material-icons">signal_cellular_alt</span>
                            <span class="material-icons">wifi</span>
                            <span class="material-icons">battery_full</span>
                        </div>
                    </div>
                    <div class="screen">
                        <!-- 页面头部 -->
                        <div class="page-header">
                            <div class="back-btn"><span class="material-icons">close</span></div>
                            <div class="page-header-title">生成分享卡片</div>
                            <span style="width:24px;"></span>
                        </div>

                        <!-- 卡片预览 -->
                        <div style="margin:16px;padding:20px;background:linear-gradient(135deg, #667eea 0%, #764ba2 100%);border-radius:16px;color:white;">
                            <div style="display:flex;align-items:center;gap:8px;margin-bottom:16px;">
                                <div style="width:32px;height:32px;background:white;border-radius:8px;display:flex;align-items:center;justify-content:center;">
                                    <span class="material-icons" style="color:#667eea;font-size:20px;">account_balance_wallet</span>
                                </div>
                                <span style="font-size:14px;font-weight:500;">AI智能记账</span>
                            </div>

                            <div style="font-size:24px;font-weight:700;margin-bottom:8px;">本月省下 ¥1,280</div>
                            <div style="font-size:13px;opacity:0.9;margin-bottom:16px;">通过智能预算管理，我比上月节省了更多</div>

                            <div style="display:flex;gap:12px;padding:12px;background:rgba(255,255,255,0.15);border-radius:10px;">
                                <div style="flex:1;text-align:center;">
                                    <div style="font-size:20px;font-weight:600;">46</div>
                                    <div style="font-size:11px;opacity:0.8;">记账天数</div>
                                </div>
                                <div style="width:1px;background:rgba(255,255,255,0.3);"></div>
                                <div style="flex:1;text-align:center;">
                                    <div style="font-size:20px;font-weight:600;">89%</div>
                                    <div style="font-size:11px;opacity:0.8;">预算控制</div>
                                </div>
                                <div style="width:1px;background:rgba(255,255,255,0.3);"></div>
                                <div style="flex:1;text-align:center;">
                                    <div style="font-size:20px;font-weight:600;">A+</div>
                                    <div style="font-size:11px;opacity:0.8;">财务健康</div>
                                </div>
                            </div>
                        </div>

                        <!-- 样式选择 -->
                        <div style="padding:0 16px 16px;">
                            <div style="font-size:13px;font-weight:500;color:var(--on-surface-variant);margin-bottom:12px;">选择样式</div>
                            <div style="display:flex;gap:12px;">
                                <div style="width:60px;height:80px;border-radius:8px;background:linear-gradient(135deg, #667eea 0%, #764ba2 100%);border:3px solid var(--primary);"></div>
                                <div style="width:60px;height:80px;border-radius:8px;background:linear-gradient(135deg, #f093fb 0%, #f5576c 100%);"></div>
                                <div style="width:60px;height:80px;border-radius:8px;background:linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);"></div>
                                <div style="width:60px;height:80px;border-radius:8px;background:linear-gradient(135deg, #43e97b 0%, #38f9d7 100%);"></div>
                            </div>
                        </div>

                        <!-- 内容选择 -->
                        <div style="padding:0 16px 16px;">
                            <div style="font-size:13px;font-weight:500;color:var(--on-surface-variant);margin-bottom:12px;">显示内容</div>
                            <div class="card" style="padding:0;">
                                <div class="list-item" style="padding:12px 16px;border-bottom:1px solid var(--outline-variant);">
                                    <div style="flex:1;font-size:14px;">显示节省金额</div>
                                    <div class="toggle active"></div>
                                </div>
                                <div class="list-item" style="padding:12px 16px;border-bottom:1px solid var(--outline-variant);">
                                    <div style="flex:1;font-size:14px;">显示记账天数</div>
                                    <div class="toggle active"></div>
                                </div>
                                <div class="list-item" style="padding:12px 16px;">
                                    <div style="flex:1;font-size:14px;">显示财务评分</div>
                                    <div class="toggle active"></div>
                                </div>
                            </div>
                        </div>

                        <!-- 分享按钮 -->
                        <div style="position:absolute;bottom:16px;left:16px;right:16px;">
                            <div style="display:flex;gap:12px;">
                                <button class="btn btn-outline" style="flex:1;min-height:48px;">保存图片</button>
                                <button class="btn btn-primary" style="flex:1;min-height:48px;">分享</button>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- 16.04 邀请好友 -->
            <div class="phone-wrapper">
                <div class="phone-label">16.04 邀请好友</div>
                <div class="phone-frame">
                    <div class="status-bar">
                        <span class="time">9:41</span>
                        <div class="icons">
                            <span class="material-icons">signal_cellular_alt</span>
                            <span class="material-icons">wifi</span>
                            <span class="material-icons">battery_full</span>
                        </div>
                    </div>
                    <div class="screen">
                        <!-- 页面头部 -->
                        <div class="page-header">
                            <div class="back-btn"><span class="material-icons">arrow_back</span></div>
                            <div class="page-header-title">邀请好友</div>
                            <span class="material-icons">help_outline</span>
                        </div>

                        <!-- 邀请奖励卡片 -->
                        <div style="margin:16px;padding:20px;background:linear-gradient(135deg, #FFB74D 0%, #FF9800 100%);border-radius:16px;color:white;text-align:center;">
                            <div style="font-size:14px;opacity:0.9;margin-bottom:4px;">邀请好友双方各得</div>
                            <div style="font-size:36px;font-weight:700;margin-bottom:8px;">7天会员</div>
                            <div style="font-size:13px;opacity:0.9;">成功邀请1位好友即可获得</div>
                        </div>

                        <!-- 我的邀请码 -->
                        <div style="padding:0 16px 16px;">
                            <div class="card" style="padding:16px;text-align:center;">
                                <div style="font-size:13px;color:var(--on-surface-variant);margin-bottom:8px;">我的专属邀请码</div>
                                <div style="font-size:28px;font-weight:700;letter-spacing:4px;color:var(--primary);margin-bottom:12px;">ABC123</div>
                                <button class="btn btn-outline" style="min-height:36px;padding:0 24px;font-size:13px;">
                                    <span class="material-icons" style="font-size:16px;margin-right:4px;">content_copy</span>
                                    复制邀请码
                                </button>
                            </div>
                        </div>

                        <!-- 分享方式 -->
                        <div style="padding:0 16px 16px;">
                            <div style="font-size:13px;font-weight:500;color:var(--on-surface-variant);margin-bottom:12px;">分享给好友</div>
                            <div style="display:flex;justify-content:space-around;">
                                <div style="text-align:center;">
                                    <div style="width:56px;height:56px;background:#07C160;border-radius:14px;display:flex;align-items:center;justify-content:center;margin:0 auto 8px;">
                                        <span class="material-icons" style="color:white;font-size:28px;">chat</span>
                                    </div>
                                    <div style="font-size:12px;color:var(--on-surface-variant);">微信</div>
                                </div>
                                <div style="text-align:center;">
                                    <div style="width:56px;height:56px;background:#07C160;border-radius:14px;display:flex;align-items:center;justify-content:center;margin:0 auto 8px;">
                                        <span class="material-icons" style="color:white;font-size:28px;">groups</span>
                                    </div>
                                    <div style="font-size:12px;color:var(--on-surface-variant);">朋友圈</div>
                                </div>
                                <div style="text-align:center;">
                                    <div style="width:56px;height:56px;background:#E6162D;border-radius:14px;display:flex;align-items:center;justify-content:center;margin:0 auto 8px;">
                                        <span class="material-icons" style="color:white;font-size:28px;">camera_alt</span>
                                    </div>
                                    <div style="font-size:12px;color:var(--on-surface-variant);">小红书</div>
                                </div>
                                <div style="text-align:center;">
                                    <div style="width:56px;height:56px;background:var(--surface-variant);border-radius:14px;display:flex;align-items:center;justify-content:center;margin:0 auto 8px;">
                                        <span class="material-icons" style="color:var(--on-surface-variant);font-size:28px;">more_horiz</span>
                                    </div>
                                    <div style="font-size:12px;color:var(--on-surface-variant);">更多</div>
                                </div>
                            </div>
                        </div>

                        <!-- 邀请记录 -->
                        <div style="padding:0 16px;">
                            <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px;">
                                <div style="font-size:13px;font-weight:500;color:var(--on-surface-variant);">邀请记录</div>
                                <span style="font-size:12px;color:var(--primary);">查看全部</span>
                            </div>
                            <div class="card" style="padding:14px 16px;">
                                <div style="display:flex;align-items:center;gap:12px;">
                                    <div style="width:40px;height:40px;background:#E3F2FD;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:16px;">👤</div>
                                    <div style="flex:1;">
                                        <div style="font-size:14px;font-weight:500;">138****6789</div>
                                        <div style="font-size:12px;color:var(--on-surface-variant);">2024-01-15 注册成功</div>
                                    </div>
                                    <div style="padding:4px 8px;background:#E8F5E9;border-radius:4px;font-size:11px;color:#66BB6A;">+7天</div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- 16.05 成就分享 -->
            <div class="phone-wrapper">
                <div class="phone-label">16.05 成就分享</div>
                <div class="phone-frame">
                    <div class="status-bar">
                        <span class="time">9:41</span>
                        <div class="icons">
                            <span class="material-icons">signal_cellular_alt</span>
                            <span class="material-icons">wifi</span>
                            <span class="material-icons">battery_full</span>
                        </div>
                    </div>
                    <div class="screen">
                        <!-- 页面头部 -->
                        <div class="page-header">
                            <div class="back-btn"><span class="material-icons">arrow_back</span></div>
                            <div class="page-header-title">我的成就</div>
                            <span class="material-icons">share</span>
                        </div>

                        <!-- 成就概览 -->
                        <div style="margin:16px;padding:20px;background:linear-gradient(135deg, #6495ED 0%, #4169E1 100%);border-radius:16px;color:white;text-align:center;">
                            <div style="font-size:48px;margin-bottom:8px;">🏆</div>
                            <div style="font-size:24px;font-weight:700;margin-bottom:4px;">理财达人</div>
                            <div style="font-size:13px;opacity:0.9;">已解锁 12/20 个成就</div>
                        </div>

                        <!-- 成就列表 -->
                        <div style="padding:0 16px;">
                            <div style="font-size:13px;font-weight:500;color:var(--on-surface-variant);margin-bottom:12px;">已解锁成就</div>

                            <div class="card" style="padding:14px 16px;margin-bottom:8px;">
                                <div style="display:flex;align-items:center;gap:12px;">
                                    <div style="width:48px;height:48px;background:linear-gradient(135deg, #FFD700 0%, #FFA500 100%);border-radius:50%;display:flex;align-items:center;justify-content:center;">
                                        <span class="material-icons" style="color:white;font-size:24px;">military_tech</span>
                                    </div>
                                    <div style="flex:1;">
                                        <div style="font-size:14px;font-weight:500;">月度记账达人</div>
                                        <div style="font-size:12px;color:var(--on-surface-variant);">连续30天记账</div>
                                    </div>
                                    <button class="btn btn-outline" style="min-height:32px;padding:0 12px;font-size:12px;">分享</button>
                                </div>
                            </div>

                            <div class="card" style="padding:14px 16px;margin-bottom:8px;">
                                <div style="display:flex;align-items:center;gap:12px;">
                                    <div style="width:48px;height:48px;background:linear-gradient(135deg, #66BB6A 0%, #43A047 100%);border-radius:50%;display:flex;align-items:center;justify-content:center;">
                                        <span class="material-icons" style="color:white;font-size:24px;">savings</span>
                                    </div>
                                    <div style="flex:1;">
                                        <div style="font-size:14px;font-weight:500;">储蓄先锋</div>
                                        <div style="font-size:12px;color:var(--on-surface-variant);">累计储蓄突破1万元</div>
                                    </div>
                                    <button class="btn btn-outline" style="min-height:32px;padding:0 12px;font-size:12px;">分享</button>
                                </div>
                            </div>

                            <div class="card" style="padding:14px 16px;margin-bottom:8px;">
                                <div style="display:flex;align-items:center;gap:12px;">
                                    <div style="width:48px;height:48px;background:linear-gradient(135deg, #9370DB 0%, #7B68EE 100%);border-radius:50%;display:flex;align-items:center;justify-content:center;">
                                        <span class="material-icons" style="color:white;font-size:24px;">pie_chart</span>
                                    </div>
                                    <div style="flex:1;">
                                        <div style="font-size:14px;font-weight:500;">预算大师</div>
                                        <div style="font-size:12px;color:var(--on-surface-variant);">连续3个月预算达标</div>
                                    </div>
                                    <button class="btn btn-outline" style="min-height:32px;padding:0 12px;font-size:12px;">分享</button>
                                </div>
                            </div>

                            <!-- 未解锁成就 -->
                            <div style="font-size:13px;font-weight:500;color:var(--on-surface-variant);margin:16px 0 12px;">待解锁</div>
                            <div class="card" style="padding:14px 16px;opacity:0.6;">
                                <div style="display:flex;align-items:center;gap:12px;">
                                    <div style="width:48px;height:48px;background:var(--surface-variant);border-radius:50%;display:flex;align-items:center;justify-content:center;">
                                        <span class="material-icons" style="color:var(--on-surface-variant);font-size:24px;">lock</span>
                                    </div>
                                    <div style="flex:1;">
                                        <div style="font-size:14px;font-weight:500;">年度坚持者</div>
                                        <div style="font-size:12px;color:var(--on-surface-variant);">连续记账365天</div>
                                    </div>
                                    <div style="font-size:12px;color:var(--on-surface-variant);">46/365</div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- 16.06 反馈收集 -->
            <div class="phone-wrapper">
                <div class="phone-label">16.06 反馈收集</div>
                <div class="phone-frame">
                    <div class="status-bar">
                        <span class="time">9:41</span>
                        <div class="icons">
                            <span class="material-icons">signal_cellular_alt</span>
                            <span class="material-icons">wifi</span>
                            <span class="material-icons">battery_full</span>
                        </div>
                    </div>
                    <div class="screen">
                        <!-- 页面头部 -->
                        <div class="page-header">
                            <div class="back-btn"><span class="material-icons">close</span></div>
                            <div class="page-header-title">意见反馈</div>
                            <span style="width:24px;"></span>
                        </div>

                        <!-- NPS评分结果 -->
                        <div style="margin:16px;padding:16px;background:#E8F5E9;border-radius:12px;display:flex;align-items:center;gap:12px;">
                            <div style="width:48px;height:48px;background:#66BB6A;border-radius:50%;display:flex;align-items:center;justify-content:center;color:white;font-size:20px;font-weight:700;">9</div>
                            <div>
                                <div style="font-size:14px;font-weight:500;color:#2E7D32;">感谢您的好评！</div>
                                <div style="font-size:12px;color:#388E3C;">您是我们的忠实用户</div>
                            </div>
                        </div>

                        <!-- 反馈问题 -->
                        <div style="padding:0 16px 16px;">
                            <div style="font-size:14px;font-weight:500;margin-bottom:12px;">您最喜欢哪些功能？(可多选)</div>
                            <div style="display:flex;flex-wrap:wrap;gap:8px;">
                                <div style="padding:8px 16px;background:var(--primary);color:white;border-radius:20px;font-size:13px;">语音记账</div>
                                <div style="padding:8px 16px;background:var(--primary);color:white;border-radius:20px;font-size:13px;">智能分类</div>
                                <div style="padding:8px 16px;background:var(--surface-variant);border-radius:20px;font-size:13px;">预算管理</div>
                                <div style="padding:8px 16px;background:var(--surface-variant);border-radius:20px;font-size:13px;">数据分析</div>
                                <div style="padding:8px 16px;background:var(--surface-variant);border-radius:20px;font-size:13px;">账单导入</div>
                                <div style="padding:8px 16px;background:var(--surface-variant);border-radius:20px;font-size:13px;">多账本</div>
                            </div>
                        </div>

                        <!-- 详细反馈 -->
                        <div style="padding:0 16px 16px;">
                            <div style="font-size:14px;font-weight:500;margin-bottom:12px;">还有什么建议？（选填）</div>
                            <textarea placeholder="告诉我们您的想法，帮助我们做得更好..." style="width:100%;height:100px;padding:12px;border:1px solid var(--outline-variant);border-radius:12px;font-size:14px;resize:none;"></textarea>
                        </div>

                        <!-- 应用商店引导 -->
                        <div style="padding:0 16px 16px;">
                            <div class="card" style="padding:16px;background:linear-gradient(135deg, #E3F2FD 0%, #BBDEFB 100%);">
                                <div style="display:flex;align-items:center;gap:12px;">
                                    <div style="width:48px;height:48px;background:white;border-radius:12px;display:flex;align-items:center;justify-content:center;">
                                        <span class="material-icons" style="color:#6495ED;font-size:28px;">star</span>
                                    </div>
                                    <div style="flex:1;">
                                        <div style="font-size:14px;font-weight:500;">去应用商店评价</div>
                                        <div style="font-size:12px;color:var(--on-surface-variant);">您的5星好评是我们最大的动力</div>
                                    </div>
                                    <span class="material-icons" style="color:var(--primary);">chevron_right</span>
                                </div>
                            </div>
                        </div>

                        <!-- 提交按钮 -->
                        <div style="position:absolute;bottom:16px;left:16px;right:16px;">
                            <button class="btn btn-primary" style="width:100%;min-height:48px;">提交反馈</button>
                        </div>
                    </div>
                </div>
            </div>

            <!-- 16.07 年度报告分享 -->
            <div class="phone-wrapper">
                <div class="phone-label">16.07 年度报告分享</div>
                <div class="phone-frame">
                    <div class="status-bar" style="background:transparent;position:absolute;z-index:10;">
                        <span class="time" style="color:white;">9:41</span>
                        <div class="icons">
                            <span class="material-icons" style="color:white;">signal_cellular_alt</span>
                            <span class="material-icons" style="color:white;">wifi</span>
                            <span class="material-icons" style="color:white;">battery_full</span>
                        </div>
                    </div>
                    <div class="screen" style="padding:0;">
                        <!-- 全屏年度报告 -->
                        <div style="height:100%;background:linear-gradient(180deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);color:white;padding:60px 24px 24px;overflow-y:auto;">
                            <!-- 年份标题 -->
                            <div style="text-align:center;margin-bottom:32px;">
                                <div style="font-size:14px;opacity:0.7;margin-bottom:4px;">我的</div>
                                <div style="font-size:36px;font-weight:700;">2024年度账单</div>
                            </div>

                            <!-- 关键数据 -->
                            <div style="margin-bottom:24px;">
                                <div style="text-align:center;margin-bottom:24px;">
                                    <div style="font-size:13px;opacity:0.7;margin-bottom:8px;">这一年，你共记录</div>
                                    <div style="font-size:48px;font-weight:700;">¥128,560</div>
                                </div>

                                <div style="display:flex;gap:12px;">
                                    <div style="flex:1;background:rgba(255,255,255,0.1);border-radius:12px;padding:16px;text-align:center;">
                                        <div style="font-size:24px;font-weight:600;">326</div>
                                        <div style="font-size:11px;opacity:0.7;">记账天数</div>
                                    </div>
                                    <div style="flex:1;background:rgba(255,255,255,0.1);border-radius:12px;padding:16px;text-align:center;">
                                        <div style="font-size:24px;font-weight:600;">1,847</div>
                                        <div style="font-size:11px;opacity:0.7;">交易笔数</div>
                                    </div>
                                    <div style="flex:1;background:rgba(255,255,255,0.1);border-radius:12px;padding:16px;text-align:center;">
                                        <div style="font-size:24px;font-weight:600;">¥8,920</div>
                                        <div style="font-size:11px;opacity:0.7;">累计储蓄</div>
                                    </div>
                                </div>
                            </div>

                            <!-- 消费之最 -->
                            <div style="background:rgba(255,255,255,0.1);border-radius:16px;padding:16px;margin-bottom:24px;">
                                <div style="font-size:14px;font-weight:500;margin-bottom:12px;">消费之最</div>
                                <div style="display:flex;gap:12px;">
                                    <div style="flex:1;text-align:center;">
                                        <div style="font-size:32px;margin-bottom:4px;">🍜</div>
                                        <div style="font-size:11px;opacity:0.7;">最爱消费</div>
                                        <div style="font-size:13px;font-weight:500;">餐饮</div>
                                    </div>
                                    <div style="flex:1;text-align:center;">
                                        <div style="font-size:32px;margin-bottom:4px;">📱</div>
                                        <div style="font-size:11px;opacity:0.7;">单笔最大</div>
                                        <div style="font-size:13px;font-weight:500;">¥6,999</div>
                                    </div>
                                    <div style="flex:1;text-align:center;">
                                        <div style="font-size:32px;margin-bottom:4px;">🏠</div>
                                        <div style="font-size:11px;opacity:0.7;">常去地点</div>
                                        <div style="font-size:13px;font-weight:500;">盒马鲜生</div>
                                    </div>
                                </div>
                            </div>

                            <!-- 分享按钮 -->
                            <div style="display:flex;gap:12px;">
                                <button class="btn" style="flex:1;min-height:48px;background:rgba(255,255,255,0.15);color:white;">保存图片</button>
                                <button class="btn" style="flex:1;min-height:48px;background:white;color:#1a1a2e;font-weight:600;">分享报告</button>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- 16.08 社交裂变活动 -->
            <div class="phone-wrapper">
                <div class="phone-label">16.08 社交裂变活动</div>
                <div class="phone-frame">
                    <div class="status-bar">
                        <span class="time">9:41</span>
                        <div class="icons">
                            <span class="material-icons">signal_cellular_alt</span>
                            <span class="material-icons">wifi</span>
                            <span class="material-icons">battery_full</span>
                        </div>
                    </div>
                    <div class="screen">
                        <!-- 页面头部 -->
                        <div class="page-header" style="background:linear-gradient(135deg, #E57373 0%, #EF5350 100%);color:white;">
                            <div class="back-btn"><span class="material-icons" style="color:white;">arrow_back</span></div>
                            <div class="page-header-title" style="color:white;">春节记账挑战</div>
                            <span class="material-icons" style="color:white;">share</span>
                        </div>

                        <!-- 活动横幅 -->
                        <div style="margin:16px;padding:20px;background:linear-gradient(135deg, #E57373 0%, #EF5350 100%);border-radius:16px;color:white;text-align:center;">
                            <div style="font-size:48px;margin-bottom:8px;">🧧</div>
                            <div style="font-size:20px;font-weight:700;margin-bottom:4px;">记账瓜分红包</div>
                            <div style="font-size:13px;opacity:0.9;margin-bottom:16px;">邀请好友一起记账，瓜分88888元红包</div>
                            <div style="display:flex;justify-content:center;gap:4px;font-size:28px;font-weight:700;">
                                <div style="background:rgba(255,255,255,0.2);padding:8px 12px;border-radius:8px;">0</div>
                                <div style="background:rgba(255,255,255,0.2);padding:8px 12px;border-radius:8px;">3</div>
                                <span>:</span>
                                <div style="background:rgba(255,255,255,0.2);padding:8px 12px;border-radius:8px;">2</div>
                                <div style="background:rgba(255,255,255,0.2);padding:8px 12px;border-radius:8px;">8</div>
                                <span>:</span>
                                <div style="background:rgba(255,255,255,0.2);padding:8px 12px;border-radius:8px;">5</div>
                                <div style="background:rgba(255,255,255,0.2);padding:8px 12px;border-radius:8px;">6</div>
                            </div>
                            <div style="font-size:11px;opacity:0.8;margin-top:8px;">活动倒计时</div>
                        </div>

                        <!-- 我的进度 -->
                        <div style="padding:0 16px 16px;">
                            <div class="card" style="padding:16px;">
                                <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px;">
                                    <div style="font-size:14px;font-weight:500;">我的战绩</div>
                                    <div style="font-size:12px;color:var(--primary);">查看排行榜</div>
                                </div>
                                <div style="display:flex;gap:16px;text-align:center;">
                                    <div style="flex:1;">
                                        <div style="font-size:24px;font-weight:700;color:#E57373;">3</div>
                                        <div style="font-size:11px;color:var(--on-surface-variant);">邀请好友</div>
                                    </div>
                                    <div style="flex:1;">
                                        <div style="font-size:24px;font-weight:700;color:#FFB74D;">15</div>
                                        <div style="font-size:11px;color:var(--on-surface-variant);">记账天数</div>
                                    </div>
                                    <div style="flex:1;">
                                        <div style="font-size:24px;font-weight:700;color:#66BB6A;">¥12.8</div>
                                        <div style="font-size:11px;color:var(--on-surface-variant);">已获红包</div>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <!-- 任务列表 -->
                        <div style="padding:0 16px;">
                            <div style="font-size:13px;font-weight:500;color:var(--on-surface-variant);margin-bottom:12px;">赚取更多红包</div>
                            <div class="card" style="padding:0;">
                                <div class="list-item" style="padding:14px 16px;border-bottom:1px solid var(--outline-variant);">
                                    <div style="width:40px;height:40px;background:#FFF3E0;border-radius:10px;display:flex;align-items:center;justify-content:center;">
                                        <span class="material-icons" style="color:#FFB74D;">person_add</span>
                                    </div>
                                    <div class="list-item-content" style="margin-left:12px;">
                                        <div class="list-item-title">邀请1位好友</div>
                                        <div class="list-item-subtitle">+5元红包</div>
                                    </div>
                                    <button class="btn btn-primary" style="min-height:32px;padding:0 12px;font-size:12px;">去邀请</button>
                                </div>
                                <div class="list-item" style="padding:14px 16px;border-bottom:1px solid var(--outline-variant);">
                                    <div style="width:40px;height:40px;background:#E8F5E9;border-radius:10px;display:flex;align-items:center;justify-content:center;">
                                        <span class="material-icons" style="color:#66BB6A;">edit_note</span>
                                    </div>
                                    <div class="list-item-content" style="margin-left:12px;">
                                        <div class="list-item-title">连续记账7天</div>
                                        <div class="list-item-subtitle">+3元红包 (5/7)</div>
                                    </div>
                                    <div style="font-size:12px;color:var(--primary);">进行中</div>
                                </div>
                                <div class="list-item" style="padding:14px 16px;">
                                    <div style="width:40px;height:40px;background:#E3F2FD;border-radius:10px;display:flex;align-items:center;justify-content:center;">
                                        <span class="material-icons" style="color:#6495ED;">share</span>
                                    </div>
                                    <div class="list-item-content" style="margin-left:12px;">
                                        <div class="list-item-title">分享年度账单</div>
                                        <div class="list-item-subtitle">+2元红包</div>
                                    </div>
                                    <button class="btn btn-outline" style="min-height:32px;padding:0 12px;font-size:12px;">去分享</button>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

        </div>
    </div>

'''

# 找到插入位置 (在 <style> 标签之前)
insert_pos = content.find('    <style>')
if insert_pos == -1:
    print('找不到 <style> 标签')
    exit(1)

# 插入新的sections
new_content = content[:insert_pos] + section_15 + section_16 + content[insert_pos:]

# 更新导航栏（添加新的nav-tab）
# 找到导航栏位置并添加新选项
nav_pattern = r'(<button class="nav-tab" onclick="showSection\(\'bill-reminder\'\)">账单提醒</button>)'
nav_replacement = r'''\1
                <button class="nav-tab" onclick="showSection('family-ledger')">家庭账本</button>
                <button class="nav-tab" onclick="showSection('nps-growth')">NPS增长</button>'''

new_content = re.sub(nav_pattern, nav_replacement, new_content)

# 更新标题中的页面数
new_content = new_content.replace('119页面', '145页面')
new_content = new_content.replace('129页面', '145页面')

# 写回文件
with open('D:/code/ai-bookkeeping/docs/prototype/app_v2_full_prototype.html', 'w', encoding='utf-8') as f:
    f.write(new_content)

print('成功添加 SECTION 15: 家庭账本与多成员管理 (8个页面)')
print('成功添加 SECTION 16: NPS与用户增长 (8个页面)')
print('总页面数: 129 + 16 = 145 页面')
