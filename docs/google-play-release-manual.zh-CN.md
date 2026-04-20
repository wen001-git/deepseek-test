# `shortvideoai` Google Play 上架操作手册

本文档说明如何将当前 Android 应用发布到 Google Play，以及从本地构建到 Play Console 提交的完整操作流程。

本文档基于当前仓库实际情况编写：

- Android 包名：`com.shortvideoai.shortvideoai`
- 代码中的应用名称：`短视频创作助手` / `Short Video AI`
- 订阅商品 ID：
  - `creator_pro_monthly`
  - `creator_pro_plus_monthly`
- 后端移动端订阅校验环境变量：
  - `GOOGLE_PLAY_PACKAGE_NAME`
  - `GOOGLE_SERVICE_ACCOUNT_JSON`

## 1. 范围与发布目标

本文档的目标是将当前 Flutter Android 应用从现有仓库状态推进到可在 Google Play 生产环境发布的状态，要求满足：

- 能从 Google Play 正常安装，不存在签名或完整性问题
- 能通过 Play Console 审核和政策合规检查
- 生产环境支持 Google Play 订阅
- 使用生产环境后端
- 默认展示英文，并支持用户在应用内切换为简体中文

本文档默认前提：

- 仅发布 Android 应用
- Play Console 账号为新的个人开发者账号，因此上线正式版前可能存在测试门槛
- Google Play Billing 仅用于数字内容或数字权益

## 2. 当前仓库状态

当前代码库已经具备：

- 位于 `mobile/` 的 Flutter Android 应用结构
- 包含 `INTERNET` 和 Billing 权限的 Android Manifest
- 移动端内置 Google Play Billing 集成
- 后端已提供 `/api/mobile/verify-subscription` 订阅校验接口
- 通过 `mobile/android/key.properties` 支持 release 签名

当前代码库还**不能直接用于 Google Play 正式发布**，原因如下：

- 如果缺少 `key.properties`，release 构建仍会回退到 debug 签名
- 移动端 Billing 流程仍需与真实 Play purchase token 的生产校验打通
- Play Console 所需的元数据、合规声明和政策材料尚未在仓库层面准备齐全
- 生产环境 Billing 后端凭据尚未配置

## 3. 发布前检查清单

在上传生产版本前，必须完成本节所有项目。

### 3.1 Android 身份与签名

1. 确认永久包名：
   - `com.shortvideoai.shortvideoai`
2. 创建上传用 keystore，并存放到安全位置。
3. 以 `mobile/android/key.properties.template` 为模板创建 `mobile/android/key.properties`。
4. 填写以下字段：
   - `storeFile`
   - `storePassword`
   - `keyAlias`
   - `keyPassword`
5. 验证 release 构建使用的是真实上传签名。
6. 不能发布任何使用 debug 签名的构建包。

推荐的 keystore 生成命令：

```bash
cd mobile/android
keytool -genkey -v -keystore app/keystore.jks \
  -alias upload \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

### 3.2 版本号管理

每次上传到 Play 前：

1. 更新 `mobile/pubspec.yaml` 中的应用版本。
2. 确保生成的 Android `versionCode` 大于上一次上传版本。
3. 确保用户可见的 `versionName` 与发布说明一致。

### 3.3 Target API 与构建合规

Google Play 对 target API 的要求会变化，必须在发布当天再次核实。

在编写本文档时，Google 当前要求为：

- 从 **2025 年 8 月 31 日** 起，新应用和应用更新必须至少 target **Android 15 / API 35**

发布前：

1. 执行一次 release 构建。
2. 确认最终 Android 构建使用的 target SDK 满足 Google Play 当前要求。
3. 在正式发布当天再次查看官方 target API 页面。

参考：

- https://developer.android.com/google/play/requirements/target-sdk

### 3.4 生产后端与订阅校验

当前后端需要以下环境变量：

- `GOOGLE_PLAY_PACKAGE_NAME`
- `GOOGLE_SERVICE_ACCOUNT_JSON`

在启用生产环境 Billing 前：

1. 创建具有 Android Publisher 权限的 Google Cloud 服务账号。
2. 生成该服务账号的 JSON 凭据。
3. 将 JSON 文件安全存放在后端服务器上。
4. 配置环境变量：
   - `GOOGLE_PLAY_PACKAGE_NAME=com.shortvideoai.shortvideoai`
   - `GOOGLE_SERVICE_ACCOUNT_JSON=/absolute/path/to/service-account.json`
5. 使用生产环境变量重启后端服务。

重要说明：

- 如果缺少这些环境变量，当前后端仍会走开发模式的订阅 token 验证逻辑。
- 在后端仍处于开发模式校验逻辑时，不能上线正式订阅支付。

### 3.5 Google Play 订阅商品配置

在 Play Console 中创建以下订阅商品：

- `creator_pro_monthly`
- `creator_pro_plus_monthly`

对每个订阅都需要完成：

1. 创建订阅商品。
2. 至少创建一个 base plan。
3. 设置价格。
4. 设置国家或地区可用范围。
5. 决定是否提供：
   - 免费试用
   - 首购优惠价
   - 仅标准月订阅
6. 激活该 base plan。

商品 ID 必须与应用代码和后端映射完全一致。

### 3.6 隐私政策、合规与审核访问

在提交审核前，需要准备：

1. 隐私政策 URL
2. 联系邮箱
3. 审核人员登录说明
4. 如应用必须登录，需提供审核测试账号
5. 内容分级问卷所需信息
6. Data safety 表单所需信息

隐私政策必须满足：

- 可公开访问
- 在线可用
- 非地区限制
- 不是 PDF 文件
- 明确标识为隐私政策

参考：

- https://support.google.com/googleplay/android-developer/answer/10144311?hl=en
- https://support.google.com/googleplay/android-developer/answer/10787469?hl=en

## 4. Play Console 配置流程

### 4.0 是否需要先开账号

需要。

如果你要把 App 发布到 Google Play，必须先注册 **Google Play Console 开发者账号**。  
这不是普通用户在 Play Store 下载应用时使用的买家账号，而是开发者后台账号。

如果你的 App 是收费的，或者应用内卖订阅、内购数字商品，那么除了开发者账号之外，还必须配置 **Google payments profile**，用于：

- 收款
- 查看销售报表
- 管理结算信息
- 管理税务和商户资料

按当前 Google 官方流程，通常需要完成以下两步：

1. 注册 Play Console 开发者账号  
2. 在 Play Console / Payments Center 中创建并关联 payments profile

当前官方说明要点：

- 注册 Play Console 开发者账号需要一次性注册费 **US$25**
- 新开发者账号需要完成身份验证
- 新个人开发者账号通常还会受到正式版上线前测试门槛约束
- 付费应用、订阅、应用内数字商品销售必须依赖 payments profile

参考：

- Play Console 入门与注册费：
  - https://support.google.com/googleplay/android-developer/answer/6112435?hl=en
- 注册支付方式与收据：
  - https://support.google.com/googleplay/android-developer/answer/9875040?hl=en
- 创建 payments profile：
  - https://support.google.com/googleplay/android-developer/answer/7161426?hl=en
- 开发者账号关联 payments profile：
  - https://support.google.com/googleplay/android-developer/answer/3092739?hl=en
- 开发者身份验证：
  - https://support.google.com/googleplay/android-developer/answer/10841920?hl=en

### 4.0.1 开发者账号注册步骤

建议按下面顺序操作：

1. 准备一个长期使用的 Google 账号  
   - 不建议使用临时邮箱
   - 最好专门用于公司或产品发布
2. 进入 Play Console 注册页面  
3. 接受 Google Play Developer Distribution Agreement  
4. 支付一次性注册费 **US$25**
5. 选择开发者账号类型：
   - `Personal`
   - `Organization`
6. 按页面要求完成身份验证
7. 补全联系信息、开发者信息和公开展示信息

如果你是个人开发者：

- 一般选择 `Personal`
- 但要注意，新个人账号通常有更严格的测试与正式版发布限制

如果你是公司、工作室或未来要长期运营商业化产品：

- 更建议注册 `Organization`
- 这样更适合商业发布、品牌展示和后续合规管理

### 4.0.2 收费 App / 订阅收款配置步骤

如果你的 App 要收费，或者卖订阅、数字内容，继续做下面的步骤：

1. 登录 Play Console
2. 进入支付相关设置页
3. 创建 `payments profile`
4. 填写真实商户信息：
   - 法定姓名或公司名称
   - 法定地址
   - 国家或地区
   - 税务信息（如要求）
   - 收款银行信息（按所在地区要求）
5. 完成 Play Console 与 payments profile 的关联

重要说明：

- Play Console 和 payments profile 绑定后，后续不能随意解绑或替换
- 如果一开始绑定错了，后续可能需要新账号并迁移应用，成本很高
- 因此第一次创建时就要使用正确主体信息

### 4.1 创建应用

在 Play Console 中：

1. 创建新应用。
2. 设置默认商店语言。
3. 设置应用类型为 `App`。
4. 根据需要设置为 `Free` 或 `Paid`。
5. 添加开发者联系邮箱。
6. 接受开发者声明和 Play App Signing 条款。

参考：

- https://support.google.com/googleplay/android-developer/answer/9859152?hl=en

### 4.2 启用 Play App Signing

建议使用 Play App Signing。

操作步骤：

1. 上传使用上传密钥签名的 App Bundle。
2. 允许 Google 管理应用签名密钥。
3. 安全保存上传密钥。
4. 导出并保存上传证书指纹，供未来集成使用。

参考：

- https://support.google.com/googleplay/android-developer/answer/9842756?hl=en-EN

### 4.3 商店展示素材

需要准备：

- 应用名称
- 简短描述
- 完整描述
- 应用图标
- 手机截图
- Feature Graphic
- 可选的宣传视频

该应用建议至少提供以下本地化商店素材：

- 英文
- 简体中文

推荐截图集合：

1. 登录页
2. 首页 / 工具箱页
3. 脚本生成页
4. 订阅 / 升级页
5. 个人中心 / 语言切换页

参考：

- https://support.google.com/googleplay/android-developer/answer/1078870?hl=en

### 4.4 App Content 与政策声明

在 Play Console 中完成所有必要项目：

1. Privacy policy
2. App access
3. Ads declaration
4. Content rating
5. Data safety
6. 如最终 manifest 或依赖触发，还需完成 Permissions declaration

参考：

- 内容分级：https://support.google.com/googleplay/android-developer/answer/9898843?hl=en
- 权限声明：https://support.google.com/googleplay/android-developer/answer/9214102?hl=en-EN

## 5. 本地构建与验证流程

所有候选发布版本都必须在本地完成验证后再上传到 Play。

### 5.1 安装依赖

```bash
cd /Users/Zhuanz/Claude/deepseek-test/mobile
flutter pub get
```

### 5.2 运行静态检查

```bash
cd /Users/Zhuanz/Claude/deepseek-test/mobile
flutter analyze
```

说明：

- 当前仓库仍存在 analyzer warning，建议在生产发布前逐项评估。
- warning 较多的构建不应直接视为可发布。

### 5.3 构建 Android App Bundle

```bash
cd /Users/Zhuanz/Claude/deepseek-test/mobile
flutter build appbundle --release
```

预期输出：

- `build/app/outputs/bundle/release/app-release.aab`

### 5.4 验证 release 假设

上传前确认：

- 构建产物使用真实上传签名
- 应用可在真实 Android 设备上启动
- 后端地址指向生产环境
- 登录可用
- 配额处理逻辑可用
- 订阅商品可从 Google Play 正确加载
- 购买流程可正常拉起
- 恢复购买流程可正常工作

## 6. 测试轨道策略

由于本文档假设使用的是**新的个人 Play Console 账号**，因此不要直接规划跳过测试上线正式版。

推荐轨道顺序：

1. Internal testing
2. Closed testing
3. Production

参考：

- https://support.google.com/googleplay/android-developer/answer/9845334

### 6.1 Internal testing

先使用 internal testing 做快速验证。

建议 internal testing 范围：

- 最多 100 名测试者
- 以团队内部成员为主
- 包含 Billing 测试账号

重点验证：

1. 从 Play 安装
2. 登录
3. 登出
4. 脚本生成功能
5. 订阅商品加载
6. 购买流程
7. 恢复购买
8. 后端权益刷新

### 6.2 Closed testing

只有 internal testing 通过后才进入 closed testing。

Closed testing 应重点验证：

1. 更多设备覆盖范围
2. Play 安装与更新行为
3. 生产后端登录
4. 付费订阅全链路行为
5. 商店页面展示和元数据质量
6. 审核说明是否准确

### 6.3 正式版上线资格说明

新的个人开发者账号，Google Play 可能会要求满足额外的正式版上线测试条件。

在计划正式版发布时间前：

1. 在 Play Console 中确认当前个人账号的正式版上线资格要求。
2. 如果控制台显示有测试时长、测试人数或其他要求，必须全部满足。
3. 不要假设 internal testing 一次就足以进入 production。

## 7. 订阅运营流程

### 7.1 License testing

在使用真实用户付款前：

1. 在 Play Console 中添加 Billing 测试账号。
2. 从 Play 测试轨道安装应用，而不是只使用本地 sideload。
3. 使用测试账号验证：
   - 成功购买
   - 取消购买
   - 恢复购买
   - 续费状态处理
   - 过期或撤销权益处理

### 7.2 后端运营校验

对每一次 Billing 测试，都需要检查后端日志，确认：

- 收到正确的 product ID
- 收到正确的 purchase token
- Google Play 校验成功
- 用户订阅等级正确激活
- 到期时间正确持久化

如果校验失败，依次检查：

1. 包名是否一致
2. 商品 ID 是否与 Play Console 完全一致
3. 服务账号权限是否正确
4. 测试账号是否具有该测试轨道和购买资格

## 8. Play 审核准备

提交正式审核前，必须保证审核人员能够顺利使用应用而不被流程阻塞。

需要准备：

1. 审核账号用户名
2. 审核账号密码
3. 简明的审核说明
4. 如存在付费墙或订阅限制，说明审核访问路径

建议的审核说明模板：

```text
测试登录账号：
Username: <review_account>
Password: <review_password>

登录后：
1. 打开 Toolbox
2. 打开 Script Writing
3. 生成内容
4. 打开 Profile 可切换语言
5. Upgrade 页面可查看订阅套餐
```

如果应用的重要区域需要付费权限才能访问，必须给审核人员提供可测试路径。

## 9. 发布当天操作流程

发布当天按以下顺序执行。

### 9.1 最终预检

1. 再次确认当前 Play target API 要求。
2. 确认后端生产环境变量已生效。
3. 确认 Play Console 中订阅商品已激活。
4. 确认隐私政策 URL 仍然可访问。
5. 确认发布说明已准备好。

### 9.2 构建与上传

1. 构建 release AAB。
2. 上传到 Play Console 目标轨道。
3. 填写发布说明。
4. 完成 Play Console 中所有未完成的任务。
5. 提交审核。

### 9.3 提交后监控

重点监控：

- Play Console 审核消息
- Android vitals
- 崩溃和 ANR
- Billing 失败率
- 后端订阅校验错误
- 登录和配额相关投诉

## 10. 回滚与热修复流程

如果正式版上线后出现严重问题：

1. 如果使用 staged rollout，立即停止 rollout。
2. 准备一个更高版本号的 hotfix 构建。
3. 重新构建并上传修复后的 AAB。
4. 更新发布说明，简要说明修复内容。
5. 如果问题影响 Billing，需要同步检查受影响用户的权益状态。

## 11. 最终 Go/No-Go 清单

只有当以下项目全部满足时，发布状态才是 **GO**：

- 上传 keystore 已创建并安全保管
- release 构建没有使用 debug 签名
- target API 满足当前 Play 要求
- 已启用 Play App Signing
- 隐私政策已上线
- Data safety 已填写完成
- 内容分级已完成
- 审核访问说明已准备好
- internal testing 已通过
- closed testing 已通过
- 如个人账号存在 production 门槛，已满足相关测试要求
- Play Console 中订阅商品已创建并激活
- 后端已在生产模式下校验真实 Play purchase
- 审核账号可正常登录
- 生产后端运行稳定

如果任一项目不满足，则发布状态为 **NO-GO**。

## 12. 参考链接

- Google Play target API 要求：
  - https://developer.android.com/google/play/requirements/target-sdk
- 创建并配置应用：
  - https://support.google.com/googleplay/android-developer/answer/9859152?hl=en
- Play App Signing：
  - https://support.google.com/googleplay/android-developer/answer/9842756?hl=en-EN
- 测试轨道：
  - https://support.google.com/googleplay/android-developer/answer/9845334
- Data safety：
  - https://support.google.com/googleplay/android-developer/answer/10787469?hl=en
- Privacy policy：
  - https://support.google.com/googleplay/android-developer/answer/10144311?hl=en
- 内容分级：
  - https://support.google.com/googleplay/android-developer/answer/9898843?hl=en
- 权限声明：
  - https://support.google.com/googleplay/android-developer/answer/9214102?hl=en-EN
- 商店素材：
  - https://support.google.com/googleplay/android-developer/answer/1078870?hl=en
- Play Billing 总览：
  - https://developer.android.com/google/play/billing/
- 订阅说明：
  - https://developer.android.com/google/play/billing/subscriptions.html
