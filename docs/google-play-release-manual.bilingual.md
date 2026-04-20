# Google Play Release Manual / Google Play 上架操作手册

This document is a bilingual operational manual for publishing `shortvideoai` to Google Play.  
本文档是 `shortvideoai` 发布到 Google Play 的中英双语操作手册。

## 1. Project Context / 项目背景

Current repo-specific facts:  
当前仓库的关键信息如下：

- Android package ID: `com.shortvideoai.shortvideoai`  
  Android 包名：`com.shortvideoai.shortvideoai`
- App name in code: `短视频创作助手` / `Short Video AI`  
  代码中的应用名称：`短视频创作助手` / `Short Video AI`
- Subscription product IDs:  
  订阅商品 ID：
  - `creator_pro_monthly`
  - `creator_pro_plus_monthly`
- Backend env vars for Play verification:  
  后端用于 Play 订阅校验的环境变量：
  - `GOOGLE_PLAY_PACKAGE_NAME`
  - `GOOGLE_SERVICE_ACCOUNT_JSON`

## 2. Release Goal / 发布目标

The release goal is to publish the Android app to Google Play in a production-ready state.  
发布目标是让 Android 应用以生产可用状态上架到 Google Play。

Required outcomes:  
必须满足以下结果：

- installable from Google Play  
  可从 Google Play 正常安装
- passes Play review and compliance checks  
  能通过 Play 审核和合规检查
- uses production backend  
  使用生产环境后端
- supports Google Play subscriptions in production  
  生产环境支持 Google Play 订阅
- defaults to English, with Simplified Chinese switchable in-app  
  默认英文显示，并支持应用内切换简体中文

## 3. What Is Already Present / 当前已具备内容

The current codebase already includes:  
当前代码库已具备：

- Flutter Android app under `mobile/`  
  位于 `mobile/` 下的 Flutter Android 应用
- Billing permission and internet permission  
  Billing 权限和网络权限
- Google Play Billing integration in the app  
  移动端已接入 Google Play Billing
- backend subscription verification endpoint  
  后端已提供订阅校验接口
- release signing configuration support through `key.properties`  
  已支持通过 `key.properties` 配置 release 签名

## 4. What Must Be Finished Before Release / 发布前必须补齐内容

### 4.1 Signing / 签名

- Create a real upload keystore  
  创建真实上传 keystore
- Create `mobile/android/key.properties` from template  
  使用模板生成 `mobile/android/key.properties`
- Never ship a release signed by debug signing  
  绝不能发布使用 debug 签名的 release 包

Recommended command / 推荐命令：

```bash
cd mobile/android
keytool -genkey -v -keystore app/keystore.jks \
  -alias upload \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

### 4.2 Versioning / 版本号管理

- Increment version in `mobile/pubspec.yaml` before every upload  
  每次上传前更新 `mobile/pubspec.yaml` 中的版本
- Ensure `versionCode` increases every release  
  确保每次发布的 `versionCode` 都递增

### 4.3 Target API / Target API 要求

- Verify the current Google Play target API requirement on release day  
  在发布当天核实 Google Play 当前 target API 要求
- Confirm the Android build meets the active Play requirement  
  确认 Android 构建满足当期 Play 要求

Reference / 参考：

- https://developer.android.com/google/play/requirements/target-sdk

### 4.4 Production Billing Verification / 生产订阅校验

- Configure backend env vars:  
  配置后端环境变量：
  - `GOOGLE_PLAY_PACKAGE_NAME`
  - `GOOGLE_SERVICE_ACCOUNT_JSON`
- Use a real Google Cloud service account with Android Publisher access  
  使用具备 Android Publisher 权限的 Google Cloud 服务账号
- Do not keep the backend in dev verification mode for production  
  生产环境不能继续使用开发模式的订阅验证逻辑

### 4.5 Subscription Setup / 订阅商品配置

Create and activate these subscriptions in Play Console:  
在 Play Console 中创建并激活以下订阅：

- `creator_pro_monthly`
- `creator_pro_plus_monthly`

Each subscription should include:  
每个订阅都应配置：

- product definition  
  商品定义
- base plan  
  base plan
- pricing  
  价格
- region availability  
  地区可用性
- optional trial or intro offer if intended  
  如有需要再配置试用或首购优惠

## 5. Policy and Review Requirements / 合规与审核要求

Before submission, prepare:  
提交审核前需准备：

- privacy policy URL  
  隐私政策 URL
- reviewer login instructions  
  审核登录说明
- test account if login is required  
  如必须登录，需提供测试账号
- content rating information  
  内容分级所需信息
- data safety information  
  Data safety 所需信息

References / 参考：

- Privacy policy / 隐私政策  
  https://support.google.com/googleplay/android-developer/answer/10144311?hl=en
- Data safety / 数据安全  
  https://support.google.com/googleplay/android-developer/answer/10787469?hl=en
- Content rating / 内容分级  
  https://support.google.com/googleplay/android-developer/answer/9898843?hl=en

## 6. Play Console Operation / Play Console 操作流程

### 6.0 Do You Need an Account First? / 是否需要先开账号？

Yes.  
需要。

To publish on Google Play, you need a **Google Play Console developer account**, not just a normal Google Play buyer account.  
如果要发布到 Google Play，你需要的是 **Google Play Console 开发者账号**，而不是普通 Play Store 用户账号。

If your app is paid, or if it sells subscriptions or digital products, you also need a **Google payments profile** for payouts and sales operations.  
如果你的 App 是收费的，或者卖订阅、数字商品，你还需要配置 **Google payments profile** 用于收款和销售管理。

Google's current official flow includes:  
Google 当前官方流程包括：

1. Create a Play Console developer account  
   创建 Play Console 开发者账号
2. Pay the one-time registration fee of **US$25**  
   支付一次性注册费 **US$25**
3. Complete developer identity verification  
   完成开发者身份验证
4. Create and link a Google payments profile if you sell paid apps, subscriptions, or in-app digital goods  
   如果你销售收费 App、订阅或应用内数字商品，还需要创建并关联 Google payments profile

Important notes:  
重要说明：

- New personal developer accounts may have production testing gates before public release  
  新的个人开发者账号在正式公开发布前可能有测试门槛
- A Play Console account and payments profile are not casually interchangeable after setup  
  Play Console 账号和 payments profile 一旦建立并绑定，后续不适合随意更换

References / 参考：

- Get started with Play Console  
  https://support.google.com/googleplay/android-developer/answer/6112435?hl=en
- Registration payment methods and receipts  
  https://support.google.com/googleplay/android-developer/answer/9875040?hl=en
- Create a payments profile  
  https://support.google.com/googleplay/android-developer/answer/7161426?hl=en
- Link Play Console to payments profile  
  https://support.google.com/googleplay/android-developer/answer/3092739?hl=en
- Verify your developer identity information  
  https://support.google.com/googleplay/android-developer/answer/10841920?hl=en

### 6.0.1 Developer Account Signup / 开发者账号注册

Recommended steps:  
建议步骤：

1. Prepare a long-term Google account  
   准备一个长期使用的 Google 账号
2. Sign up for a Play Console developer account  
   注册 Play Console 开发者账号
3. Accept the Developer Distribution Agreement  
   接受开发者分发协议
4. Pay the **US$25** one-time registration fee  
   支付 **US$25** 一次性注册费
5. Choose account type: `Personal` or `Organization`  
   选择账号类型：`Personal` 或 `Organization`
6. Complete identity verification  
   完成身份验证

Recommendation:  
建议：

- choose `Organization` if this app is a long-term commercial product  
  如果这是一个长期商业化产品，更建议使用 `Organization`
- choose `Personal` only if you truly publish as an individual and accept the extra testing restrictions  
  只有在你确实以个人主体发布，并接受额外测试限制时，才建议用 `Personal`

### 6.0.2 Payments Profile for Paid Apps / 收费应用的收款资料配置

If the app is paid or sells subscriptions, complete this after the developer account is ready:  
如果应用收费或卖订阅，在开发者账号就绪后继续完成以下步骤：

1. Open Play Console payments settings  
   打开 Play Console 支付设置
2. Create a `payments profile`  
   创建 `payments profile`
3. Enter legal business or personal identity information  
   填写真实主体信息
4. Add settlement and tax details as required by your region  
   按地区要求补充结算与税务信息
5. Link the profile to your developer account  
   将其与开发者账号关联

Warning:  
警告：

- once linked, the payments profile is not something you should assume can be freely swapped later  
  一旦绑定，不要假设 payments profile 后续可以随意替换

### 6.1 Create App / 创建应用

In Play Console:  
在 Play Console 中：

1. Create a new app  
   创建新应用
2. Set default store language  
   设置默认商店语言
3. Set app type to `App`  
   设置应用类型为 `App`
4. Set distribution to free or paid  
   设置免费或付费
5. Add contact email  
   添加联系邮箱
6. Accept declarations and signing terms  
   接受声明和签名条款

### 6.2 Enable Play App Signing / 启用 Play App Signing

- Upload the app bundle signed with the upload key  
  上传使用上传密钥签名的 app bundle
- Let Google manage the app signing key  
  让 Google 托管应用签名密钥
- Keep the upload key and certificate fingerprint securely  
  安全保存上传密钥和证书指纹

### 6.3 Prepare Store Assets / 准备商店素材

Prepare:  
需要准备：

- app name / 应用名
- short description / 简短描述
- full description / 完整描述
- app icon / 应用图标
- phone screenshots / 手机截图
- feature graphic / Feature Graphic
- optional promo video / 可选宣传视频

Recommended listing languages:  
建议的商店页面语言：

- English
- 简体中文

## 7. Build and Validation / 本地构建与验证

### 7.1 Install dependencies / 安装依赖

```bash
cd /Users/Zhuanz/Claude/deepseek-test/mobile
flutter pub get
```

### 7.2 Static analysis / 静态检查

```bash
cd /Users/Zhuanz/Claude/deepseek-test/mobile
flutter analyze
```

### 7.3 Build AAB / 构建 AAB

```bash
cd /Users/Zhuanz/Claude/deepseek-test/mobile
flutter build appbundle --release
```

Expected output / 预期产物：

- `build/app/outputs/bundle/release/app-release.aab`

### 7.4 Validate release behavior / 验证 release 行为

Confirm all of the following:  
确认以下项目全部通过：

- release is signed correctly  
  release 已正确签名
- app starts on a physical Android device  
  可在真实 Android 设备启动
- production backend is used  
  使用生产环境后端
- login works  
  登录正常
- quota behavior works  
  配额限制正常
- subscription products load from Play  
  订阅商品能从 Play 正常加载
- purchase and restore both work  
  购买和恢复购买都正常

## 8. Testing Track Strategy / 测试轨道策略

Recommended track order:  
推荐轨道顺序：

1. Internal testing
2. Closed testing
3. Production

For new personal developer accounts, production eligibility may require testing milestones.  
对于新的个人开发者账号，正式版上线资格可能要求先满足测试门槛。

Reference / 参考：

- https://support.google.com/googleplay/android-developer/answer/9845334

## 9. Release Day Procedure / 发布当天流程

Before release:  
发布前：

1. Re-check target API requirements  
   再次核实 target API 要求
2. Confirm backend production env vars are active  
   确认后端生产环境变量已生效
3. Confirm subscriptions are active in Play Console  
   确认 Play Console 中订阅已激活
4. Confirm privacy policy is live  
   确认隐私政策在线可访问
5. Prepare release notes  
   准备发布说明

Release steps:  
发布步骤：

1. Build release AAB  
   构建 release AAB
2. Upload to the selected track  
   上传到目标测试轨道或生产轨道
3. Fill release notes  
   填写发布说明
4. Complete all pending Play Console tasks  
   完成所有待处理的 Play Console 项
5. Submit for review  
   提交审核

## 10. Go / No-Go Checklist / 最终上线检查

Release is `GO` only if:  
只有当以下条件全部满足时，发布才是 `GO`：

- real upload keystore exists  
  已有真实上传 keystore
- release does not use debug signing  
  release 未使用 debug 签名
- target API is compliant  
  target API 合规
- Play App Signing is enabled  
  已启用 Play App Signing
- privacy policy is live  
  隐私政策在线可访问
- data safety is completed  
  Data safety 已完成
- content rating is completed  
  内容分级已完成
- internal and closed testing passed  
  internal 和 closed testing 已通过
- subscriptions are active  
  订阅商品已激活
- production backend verifies real Play purchases  
  生产后端可校验真实 Play purchase
- review login works  
  审核登录可用

If any of the above is missing, the release is `NO-GO`.  
如果任一条件不满足，则发布状态为 `NO-GO`。

## 11. References / 参考链接

- Target API  
  https://developer.android.com/google/play/requirements/target-sdk
- Create app  
  https://support.google.com/googleplay/android-developer/answer/9859152?hl=en
- Play App Signing  
  https://support.google.com/googleplay/android-developer/answer/9842756?hl=en-EN
- Testing tracks  
  https://support.google.com/googleplay/android-developer/answer/9845334
- Data safety  
  https://support.google.com/googleplay/android-developer/answer/10787469?hl=en
- Privacy policy  
  https://support.google.com/googleplay/android-developer/answer/10144311?hl=en
- Content rating  
  https://support.google.com/googleplay/android-developer/answer/9898843?hl=en
- Store listing assets  
  https://support.google.com/googleplay/android-developer/answer/1078870?hl=en
- Play Billing  
  https://developer.android.com/google/play/billing/
