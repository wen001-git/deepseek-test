class AppStrings {
  final bool isZh;
  const AppStrings(this.isZh);

  String _s(String en, String zh) => isZh ? zh : en;

  // ── General ────────────────────────────────────────────────────────────────
  String get appName       => _s('Short Video AI', '短视频创作助手');
  String get language      => _s('Language', '语言');
  String get english       => 'English';
  String get chinese       => '中文';
  String get generate      => _s('Generate', '生成');
  String get regenerate    => _s('Regenerate', '重新生成');
  String get back          => _s('Back', '返回');
  String get makeScript    => _s('Make Script', '制作脚本');
  String get viewScript    => _s('Make Script →', '去制作脚本 →');
  String get optionalStrengths => _s('Strengths (optional)', '特长优势（可选）');
  String durationSeconds(int n) => isZh ? '时长：$n 秒' : 'Duration: $n s';
  String durationSliderLabel(int n) => isZh ? '$n秒' : '$n s';
  String get contentDirectionSingle => _s('Content Direction (single)', '内容方向（单选）');
  String get viralElementsMulti => _s('Viral Elements (multi)', '爆款元素（可多选）');
  String get monetizeDirectionSingle => _s('Monetization Direction (single)', '变现方向（单选）');
  String get contentToneMulti => _s('Content Tone (multi)', '内容基调（可多选）');
  String sourceSnippet(String platform, String snippet) =>
      isZh ? '来源：$platform\n$snippet' : 'Source: $platform\n$snippet';
  String platformViews(String platform, dynamic views) =>
      isZh ? '$platform · $views播放' : '$platform · $views views';
  String get parseLinkMode => _s('Parse Link', '链接解析');
  String get searchVideoMode => _s('Search Video', '搜索视频');
  String get manualInputMode => _s('Manual Input', '手动输入');
  String get videoLinkOrShareText => _s('Video Link or Share Text *', '视频链接或分享文案 *');
  String get pasteVideoLinkOrShareText =>
      _s('Paste a Douyin/Bilibili/Xiaohongshu link or share text', '粘贴抖音/B站/小红书链接或分享文案');
  String get supportedPlatformsHint =>
      _s('Supported: Douyin, Bilibili, Xiaohongshu, WeChat Channels links',
          '支持：抖音、B站、小红书、视频号链接');
  String get searchKeywordLabel => _s('Search Keyword', '搜索关键词');
  String get searchKeywordHint => _s('e.g. weight loss, side hustle', '例如：减肥、副业赚钱');
  String get searchNow => _s('Search', '搜索');
  String get videoTitle => _s('Video Title *', '视频标题 *');
  String get videoContentOptional => _s('Video Content (optional)', '视频内容（可选）');
  String get pasteVideoContent => _s('Paste script or content description', '粘贴视频文案或内容描述');
  String get referenceVideoTitle => _s('Reference Video Title *', '参考视频标题 *');
  String get referenceVideoContent => _s('Reference Video Content (optional)', '参考视频内容（可选）');
  String get myTopicLabel => _s('My Topic *', '我的话题 *');
  String get myTopicHint => _s('e.g. How to learn guitar fast', '例如：如何快速学会吉他');
  String get styleLabel => _s('Style', '风格');
  String get pasteOriginalContentError => _s('Please paste original content', '请粘贴原始文案');
  String get fillReferenceTopicError =>
      _s('Please fill in reference title and your topic', '请填写参考视频标题和你的话题');
  String get pasteVideoLinkError => _s('Please paste video link or share text', '请粘贴视频链接或分享文案');
  String get chooseSearchVideoError => _s('Please search and select a video first', '请先搜索并选择一个视频');
  String get enterVideoTitleError => _s('Please enter video title', '请输入视频标题');
  String get enterSearchKeywordError => _s('Please enter a search keyword', '请输入搜索关键词');
  String get fillTopicSceneError =>
      _s('Please fill in topic and shooting scene', '请填写视频主题和拍摄场景');
  String get fillIndustryError => _s('Please fill in industry', '请填写行业领域');
  String get videoTopic => _s('Video Topic *', '视频主题 *');
  String get shootingScene => _s('Shooting Scene *', '拍摄场景 *');
  String get shootingSceneHint => _s('e.g. bedroom, park, studio', '例如：室内卧室、户外公园');
  String get shootingEquipment => _s('Equipment', '拍摄设备');
  String streamingChars(int n) => isZh ? '生成中 $n 字...' : 'Generating $n chars...';

  String get copy => _s('Copy', '复制');
  String get share => _s('Share', '分享');
  String get copiedToClipboard => _s('Copied to clipboard', '已复制到剪贴板');
  String get quickGenerate => _s('Quick Generate', '快速生成');
  String get deepThink => _s('Deep Think', '深度思考');
  String get connectingAi => _s('Connecting to AI…', '正在连接 AI…');
  String get aiThinkingWait => _s('AI is thinking, please wait…', 'AI 思考中，请稍候…');
  String get outputStartingSoon => _s('Output is about to begin…', '即将开始输出，请耐心等待…');
  String get generating => _s('Generating…', '生成中…');
  String get deepThinkingDelay =>
      _s('Deep reasoning in progress, usually 20-40 seconds…', '深度思考中，通常需要 20-40 秒…');

  String get signInFailedNetwork =>
      _s('Sign in failed. Check your network connection.', '登录失败，请检查网络连接');
  String get purchaseFailedUnknown => _s('unknown error', '未知错误');
  String purchaseFailed(String message) =>
      isZh ? '购买失败：$message' : 'Purchase failed: $message';
  String get playUnavailable => _s(
      'Google Play subscriptions are unavailable. Confirm the device has Play Store and the plans are configured in Play Console.',
      'Google Play 订阅服务不可用。请确认设备已安装 Play 商店，且订阅套餐已在 Play Console 配置。');
  String get loadPlansFailed =>
      _s('Failed to load subscription plans. Check your network and try again.',
          '加载订阅信息失败，请检查网络后重试');
  String get launchPurchaseFailed =>
      _s('Unable to start purchase. Please try again later.', '无法发起购买，请稍后再试');
  String get verifySubscriptionFailed =>
      _s('Subscription verification failed. Please contact support.',
          '订阅验证失败，请联系客服');

  String get sessionExpired => _s('Please sign in again', '未登录，请重新登录');
  String get noAccessFeature => _s('Your account cannot access this feature', '账号无权限访问此功能');
  String get dailyLimitReached => _s('You have reached today\'s usage limit', '今日使用次数已达上限');
  String serverError(int code) => _s('Server error ($code)', '服务器错误 ($code)');

  // Tier names
  String get tierFree      => _s('Free', '免费版');
  String get tierPro       => 'Pro';
  String get tierProPlus   => 'Pro+';
  String get tierAdmin     => _s('Admin', '管理员');
  String tierName(String tier) {
    switch (tier) {
      case 'pro':       return tierPro;
      case 'pro_plus':  return tierProPlus;
      case 'admin':     return tierAdmin;
      default:          return tierFree;
    }
  }

  // ── Login ──────────────────────────────────────────────────────────────────
  String get loginTitle    => _s('Sign in to your account', '登录您的账号');
  String get username      => _s('Username', '用户名');
  String get password      => _s('Password', '密码');
  String get usernameHint  => _s('Enter username', '请输入用户名');
  String get passwordHint  => _s('Enter password', '请输入密码');
  String get loginBtn      => _s('Sign In', '登 录');
  String get noAccount     => _s('No account? Contact admin', '没有账号？请联系管理员开通');

  // ── Home ───────────────────────────────────────────────────────────────────
  String get toolbox           => _s('Toolbox', '工具箱');
  String get myTab             => _s('My', '我的');
  String get myAccountTitle    => _s('My Account', '我的账号');
  String get accountPlanning   => _s('Account Planning', '账号规划');
  String get accountPlanningSub=> _s('Build your account strategy', '打造专属账号策略');
  String get viralTopics       => _s('Viral Topics', '爆款选题');
  String get viralTopicsSub    => _s('Find high-potential topics', '发现高潜力视频选题');
  String get monetizeTopics    => _s('Monetization Topics', '变现选题');
  String get monetizeTopicsSub => _s('Find commercial content', '挖掘带货&商业选题');
  String get scriptWriting     => _s('Script Writing', '脚本制作');
  String get scriptWritingSub  => _s('Generate full video scripts', '一键生成完整视频脚本');
  String get contentRewrite    => _s('Content Rewrite', '文案二创');
  String get contentRewriteSub => _s('Rewrite & improve content', '优化改写现有文案');
  String get breakdown         => _s('Content Breakdown', '爆款拆解');
  String get breakdownSub      => _s('Analyze viral structure', '学习爆款视频结构');
  String get imitate           => _s('Content Imitation', '爆款仿写');
  String get imitateSub        => _s('Imitate viral style', '仿写爆款风格文案');
  String get director          => _s('Director Column', '编导专栏');
  String get directorSub       => _s('Professional directing tips', '专业编导思维与技巧');
  String get hotTrends         => _s('Hot Trends', '热点追踪');
  String get hotTrendsSub      => _s('Real-time trending topics', '实时热点话题追踪');

  // ── Profile ────────────────────────────────────────────────────────────────
  String get accountType   => _s('Account Type', '账号类型');
  String get adminRole     => _s('Admin', '管理员');
  String get normalUser    => _s('User', '普通用户');
  String get subscription  => _s('Subscription', '订阅套餐');
  String get dailyLimit    => _s('Daily Limit', '每日生成次数');
  String get expiresAt     => _s('Expires', '到期时间');
  String get upgradeBtn    => _s('Upgrade', '升级订阅');
  String get logout        => _s('Log Out', '退出登录');
  String timesPerDay(int n)=> isZh ? '$n 次/天' : '$n times/day';

  // ── Paywall ────────────────────────────────────────────────────────────────
  String get upgradeTitle    => _s('Upgrade', '升级订阅');
  String get unlockAll       => _s('Unlock All AI Features', '解锁全部AI创作功能');
  String get paywallSubtitle => _s(
      'Generate scripts, topics & shot lists every day',
      '每天生成高质量短视频脚本、选题、分镜…');
  String get feat1           => _s('📝 Script Writing & Shot Table', '📝 脚本制作 & 分镜拍摄表');
  String get feat2           => _s('🎯 Viral & Monetization Topics', '🎯 爆款选题 & 变现选题');
  String get feat3           => _s('🔍 Multi-platform Video Search', '🔍 多平台视频搜索');
  String get feat4           => _s('✍️ Content Rewrite & Imitation', '✍️ 文案二创 & 爆款仿写');
  String get feat5           => _s('📊 Content Planning & Positioning', '📊 内容规划 & 定位分析');
  String get feat6           => _s('🎬 Director Column', '🎬 编导专栏');
  String get loadError       => _s('Failed to load plans, check network', '无法加载订阅信息，请检查网络');
  String get reload          => _s('Retry', '重新加载');
  String get restore         => _s('Restore Purchases', '恢复已购订阅');
  String get autoRenewNote   => _s(
      'Subscription auto-renews via Google Play. Cancel in Google Play settings.',
      '订阅将通过Google Play自动续费。取消订阅请前往Google Play设置。');
  String get perMonth        => _s('/month', '/月');
  String timesPerDayN(int n) => isZh ? '每天可生成 $n 次' : '$n times/day';
  String subscribeTo(String tier) => isZh ? '订阅$tier' : 'Subscribe to $tier';

  // ── Script Writing ─────────────────────────────────────────────────────────
  String get scriptTitle     => _s('Script Writing', '脚本制作');
  String get topic           => _s('Topic *', '视频主题 *');
  String get topicHint       => _s('e.g. How to lose weight in 30 days', '例如：30天减肥成功的秘密');
  String get videoType       => _s('Video Type', '视频类型');
  String get contentStyle    => _s('Content Style', '内容风格');
  String get generateScript  => _s('Generate Script', '生成脚本');
  String get pleaseEnterTopic=> _s('Please enter a topic', '请输入视频主题');

  // ── Shot Table ─────────────────────────────────────────────────────────────
  String get shotTableTitle  => _s('Shot Table', '分镜拍摄表');
  String get scriptLabel     => _s('Script *', '视频脚本 *');
  String get pasteScript     => _s('Paste script content', '粘贴已生成的脚本内容');
  String get generateShots   => _s('Generate Shot Table', '生成分镜表');
  String get pleaseEnterScript => _s('Please paste a script', '请粘贴视频脚本');

  // ── Positioning ────────────────────────────────────────────────────────────
  String get positioningTitle => _s('Positioning Analysis', '定位分析');
  String get industry         => _s('Industry *', '行业领域 *');
  String get industryHint     => _s('e.g. Fitness, Cooking, Finance', '例如：健身、美食、理财');
  String get strengths        => _s('Strengths *', '特长优势 *');
  String get strengthsHint    => _s('e.g. 10 years of cooking experience', '例如：10年厨师经验');
  String get platforms        => _s('Platforms', '发布平台');
  String get contentFormats   => _s('Content Formats', '内容形式');
  String get analyzeBtn       => _s('Analyze', '开始分析');
  String get pleaseFillFields => _s('Please fill in industry and strengths', '请填写行业领域和特长优势');

  // ── Viral / Monetize Topics ────────────────────────────────────────────────
  String get viralTitle       => _s('Viral Topics', '爆款选题');
  String get monetizeTitle    => _s('Monetization Topics', '变现选题');
  String get accountTypeLabel => _s('Account Type', '账号类型');
  String get targetAudience   => _s('Target Audience', '目标受众');
  String get niche            => _s('Niche / Industry', '细分领域');

  // ── Content Rewrite ────────────────────────────────────────────────────────
  String get rewriteTitle     => _s('Content Rewrite', '文案二创');
  String get originalContent  => _s('Original Content *', '原始文案 *');
  String get pasteContent     => _s('Paste original content', '粘贴原始文案');

  // ── Breakdown ──────────────────────────────────────────────────────────────
  String get breakdownTitle   => _s('Content Breakdown', '爆款拆解');
  String get viralContent     => _s('Viral Content *', '爆款内容 *');
  String get pasteViral       => _s('Paste viral content to analyze', '粘贴要拆解的爆款内容');

  // ── Imitate ────────────────────────────────────────────────────────────────
  String get imitateTitle     => _s('Content Imitation', '爆款仿写');
  String get referenceContent => _s('Reference Content *', '参考内容 *');
  String get newTopic         => _s('New Topic *', '新主题 *');

  // ── Search ────────────────────────────────────────────────────────────────
  String get searchTitle      => _s('Viral Search', '爆款搜索');
  String get keyword          => _s('Keyword *', '搜索关键词 *');
  String get searchBtn        => _s('Search', '搜索');

  // ── Breakdown Sharetext ────────────────────────────────────────────────────
  String get breakdownSharetextTitle => _s('Viral Share Text', '爆款分享文案拆解');

  // ── Director ──────────────────────────────────────────────────────────────
  String get directorTitle    => _s('Director Column', '编导专栏');
  String get directorTopic    => _s('Topic / Question *', '主题/问题 *');

  // ── Content Plan ──────────────────────────────────────────────────────────
  String get contentPlanTitle => _s('Content Plan', '内容规划');

  // ── Account Planning ──────────────────────────────────────────────────────
  String get accountPlanningTitle  => _s('Account Planning', '账号规划');
  String get step1Title            => _s('Step 1: Positioning Analysis', 'Step 1: 定位分析');
  String get step2Title            => _s('Step 2: Content Plan', 'Step 2: 内容规划');
  String get step1Label            => _s('Positioning', '定位分析');
  String get step1Subtitle         => _s('Analyze account positioning and target audience', '分析账号定位、目标人群和内容方向');
  String get step2Label            => _s('Content Plan', '内容规划');
  String get step2Subtitle         => _s('Create a content plan based on positioning', '基于定位分析结果，制定内容发布计划');
  String get industryAutoFill      => _s('Auto-filled from Step 1', '自动填入（来自步骤一）');
  String get audienceAutoFill      => _s('Auto-extracted from positioning result', '自动提取（来自定位分析结果）');
  String get startPositioning      => _s('Start Analysis', '开始定位分析');
  String generatingChars(int n)    => isZh ? '生成中 $n 字...' : 'Generating... $n chars';
  String get unlockAfterStep1      => _s('Complete Step 1 to unlock', '完成步骤一后解锁');
  String get pleaseFillIndustryPlatform => _s('Please fill in industry and platform', '请填写行业领域和目标平台');
  String get accountTypeOpts       => _s('Account Type', '账号类型');
  String get contentStylePref      => _s('Content Style', '内容风格偏好');
  String get contentFormatPref     => _s('Content Format', '内容形式偏好');
  String get targetPlatform        => _s('Target Platform', '目标平台');
  String get currentFollowers      => _s('Current Followers', '当前粉丝量');
  String get platform              => _s('Platform', '发布平台');
  String get followers             => _s('Followers', '粉丝量');
  String get dailyHours            => _s('Daily Hours', '每日可用时间');
  String get generateContentPlan   => _s('Generate Content Plan', '生成内容规划');
  String get generatePositioning   => _s('Analyze', '开始分析');
  String get makeShotTable         => _s('Make Shot Table', '生成分镜表');
  String get useLastInput          => _s('Use Last Input', '使用上次输入');
  String get pleaseFillStep1       => _s('Please fill in industry and strengths', '请填写行业领域和特长优势');
  String get pleaseFillPlatform    => _s('Please select a platform', '请选择发布平台');

  // ── Content Plan View ─────────────────────────────────────────────────────
  String get postsPerDay        => _s('Posts/day', '每天发布');
  String postsCount(dynamic n)  => isZh ? '$n 条' : '$n posts';
  String get bestPostTimes      => _s('Best Post Times', '最佳发布时间');
  String get contentTypeDist    => _s('Content Type Distribution', '内容类型分布');
  String get thirtyDayCalendar  => _s('30-day Publishing Calendar', '30天发布日历');
  String get growthAdvice       => _s('Growth Advice', '成长建议');
  String get whyPostTimes       => _s('💡 Why these post times?', '💡 为什么选这些发布时间？');
  String get whyContentMix      => _s('💡 Why this content distribution?', '💡 为什么这样分配内容类型？');
  String get whyWeeklyRhythm    => _s('💡 Why this weekly rhythm?', '💡 为什么这样安排一周节奏？');

  // ── Shot Table View ───────────────────────────────────────────────────────
  String get seconds            => _s('s', '秒');
  String get sceneLabel         => _s('Scene', '画面');
  String get dialogLabel        => _s('Dialog', '台词');
  String get notesLabel         => _s('Notes', '备注');
  String get aiPromptsTitle     => _s('AI Prompts · Midjourney / Runway', 'AI 提示词 · Midjourney / Runway');
  String get textToImageLabel   => _s('Text-to-Image', '文生图');
  String get imageToVideoLabel  => _s('Image-to-Video', '图生视频');
  String get zhPrefix           => _s('ZH: ', '中：');
  String copiedPrompt(String label) => isZh ? '已复制 $label 英文提示词' : 'Copied $label prompt';
  String get copyPromptTooltip  => _s('Copy prompt', '复制英文提示词');

  // ── Hot Trends ────────────────────────────────────────────────────────────
  String get hotTrendsTitle   => _s('Hot Trends', '热点追踪');
  String get updatedAt        => _s('Updated at', '更新于');

  String videoTypeLabel(String value) {
    switch (value) {
      case '通用': return _s('General', value);
      case '知识科普': return _s('Educational', value);
      case '生活记录': return _s('Lifestyle', value);
      case '剧情故事': return _s('Storytelling', value);
      case '产品测评': return _s('Product Review', value);
      case '才艺展示': return _s('Talent Showcase', value);
      default: return value;
    }
  }

  String styleOptionLabel(String value) {
    switch (value) {
      case '幽默': return _s('Humorous', value);
      case '治愈': return _s('Healing', value);
      case '励志': return _s('Motivational', value);
      case '悬疑': return _s('Suspenseful', value);
      case '温情': return _s('Warm', value);
      case '干货': return _s('Practical', value);
      default: return value;
    }
  }

  String platformOptionLabel(String value) {
    switch (value) {
      case '抖音': return 'Douyin';
      case 'B站': return _s('Bilibili', value);
      case '小红书': return _s('Xiaohongshu', value);
      case '视频号': return _s('WeChat Channels', value);
      case 'YouTube': return 'YouTube';
      default: return value;
    }
  }

  String contentFormatOptionLabel(String value) {
    switch (value) {
      case '口播': return _s('Talking Head', value);
      case 'Vlog': return 'Vlog';
      case '知识讲解': return _s('Explainer', value);
      case '剧情': return _s('Drama', value);
      case '测评': return _s('Review', value);
      case '教程': return _s('Tutorial', value);
      default: return value;
    }
  }

  String viralDirectionLabel(String value) {
    switch (value) {
      case '晒过程': return _s('Show the Process', value);
      case '讲故事': return _s('Tell a Story', value);
      case '教知识': return _s('Teach Knowledge', value);
      case '聊观点': return _s('Share Opinions', value);
      default: return value;
    }
  }

  String viralElementLabel(String value) {
    switch (value) {
      case '成本的': return _s('Cost-focused', value);
      case '人群的': return _s('Audience-focused', value);
      case '奇葩的': return _s('Unusual', value);
      case '最差的': return _s('Worst-case', value);
      case '怀旧的': return _s('Nostalgic', value);
      case '荷尔蒙的': return _s('Energetic', value);
      case '头牌的': return _s('Top-tier', value);
      case '颜值的': return _s('Appearance-focused', value);
      default: return value;
    }
  }

  String followerRangeLabel(String value) {
    switch (value) {
      case '0 - 1千': return _s('0 - 1k', value);
      case '1千 - 1万': return _s('1k - 10k', value);
      case '1万 - 10万': return _s('10k - 100k', value);
      case '10万 - 100万': return _s('100k - 1M', value);
      case '100万以上': return _s('1M+', value);
      default: return value;
    }
  }

  String monetizeDirectionLabel(String value) {
    switch (value) {
      case '广告接单': return _s('Sponsored Ads', value);
      case '带货变现': return _s('Product Sales', value);
      case '知识付费': return _s('Paid Knowledge', value);
      case '私域引流': return _s('Private Traffic', value);
      case '直播带货': return _s('Livestream Sales', value);
      default: return value;
    }
  }

  String toneOptionLabel(String value) {
    switch (value) {
      case '种草氛围': return _s('Recommendation Mood', value);
      case '专业信任': return _s('Professional Trust', value);
      case '生活场景': return _s('Lifestyle Scene', value);
      case '测评对比': return _s('Review Comparison', value);
      case '教程干货': return _s('Tutorial Value', value);
      default: return value;
    }
  }

  String equipmentOptionLabel(String value) {
    switch (value) {
      case '仅手机': return _s('Phone Only', value);
      case '手机+补光灯': return _s('Phone + Light', value);
      case '相机': return _s('Camera', value);
      case '专业摄像机': return _s('Pro Camcorder', value);
      case '无人机': return _s('Drone', value);
      default: return value;
    }
  }

  String accountTypeOptionLabel(String value) {
    switch (value) {
      case '个人品牌': return _s('Personal Brand', value);
      case '企业号': return _s('Business Account', value);
      case '品牌号': return _s('Brand Account', value);
      case '机构号': return _s('Organization Account', value);
      default: return value;
    }
  }

  String contentStyleOptionLabel(String value) {
    switch (value) {
      case '干货知识': return _s('Practical Knowledge', value);
      case '真实经历': return _s('Real Experience', value);
      case '生活场景': return _s('Lifestyle Scene', value);
      case '特技风格': return _s('Stylized', value);
      case '励志鸡汤': return _s('Motivational', value);
      case '热点追踪': return _s('Trend Tracking', value);
      default: return value;
    }
  }

  String dailyHoursOptionLabel(String value) {
    switch (value) {
      case '0.5小时内': return _s('Under 0.5 hour', value);
      case '1-2小时': return _s('1-2 hours', value);
      case '2-4小时': return _s('2-4 hours', value);
      case '4小时以上': return _s('4+ hours', value);
      default: return value;
    }
  }
}
