import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../app/app_palette.dart';
import '../../core/ai_core_paths.dart';
import '../../core/ai_server_service.dart';
import '../../core/models/news_item.dart';
import '../../core/news_service.dart';
import '../../core/search_service.dart';
import '../../core/models/welcome_settings.dart';
import '../../core/services/welcome_settings_service.dart';
import '../../core/services/institute_logo_service.dart';
import '../admin/admin_panel_route.dart';
import '../shared/answer_images_reveal.dart';
import '../shared/answer_videos_row.dart';
import '../shared/background_glow.dart';
import '../shared/developer_footer.dart';
import '../shared/fullscreen_image_page.dart';
import '../shared/news_carousel.dart';
import '../shared/paragraph_shimmer.dart';
import '../shared/streaming_answer_text.dart';
import 'chat_bubbles.dart';
import 'search_bar_field.dart';
import 'welcome_screen.dart';

class EduCoreScreen extends StatefulWidget {
  const EduCoreScreen({super.key, this.onToggleTheme});

  /// Kept for compatibility; theme toggle lives in the window title bar.
  final VoidCallback? onToggleTheme;

  @override
  State<EduCoreScreen> createState() => _EduCoreScreenState();
}

class _EduCoreScreenState extends State<EduCoreScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final AiServerService _serverService = AiServerService();
  final SearchService _searchService = SearchService();
  final NewsService _newsService = NewsService();

  bool _hasSearched = false;
  bool _isLoading = false;
  bool _isStreaming = false;
  bool _autoScrollEnabled = true;
  bool _isServerStarting = true;
  String? _serverError;

  String _currentQuestion = '';
  String _streamingAnswer = '';
  List<String> _answerImages = [];
  List<String> _answerVideos = [];
  bool _showAnswerMedia = false;
  String? _aiCoreDirectory;
  File? _instituteLogo;
  List<NewsItem> _newsItems = [];
  String? _articlePreviewImage;
  WelcomeSettings _welcomeSettings = WelcomeSettings.defaults;

  Timer? _streamingTimer;
  DateTime? _streamStartTime;
  Duration _streamDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadInstituteLogo();
    _loadWelcomeSettings();
    _bootstrapServer();
    _loadNews();
  }

  Future<void> _loadWelcomeSettings() async {
    final settings = await WelcomeSettingsService.load();
    if (!mounted) return;
    setState(() => _welcomeSettings = settings);
  }

  Future<void> _loadNews() async {
    try {
      await _serverService.ensureRunning();
      final items = await _newsService.fetchNews();
      if (!mounted) return;
      setState(() => _newsItems = items);
    } catch (_) {
      if (!mounted) return;
      setState(() => _newsItems = []);
    }
  }

  void _loadInstituteLogo() {
    setState(() => _instituteLogo = InstituteLogoService.resolve());
  }

  Future<void> _bootstrapServer() async {
    try {
      await _serverService.ensureRunning();
      if (!mounted) return;
      setState(() {
        _isServerStarting = false;
        _serverError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isServerStarting = false;
        _serverError = e.toString();
      });
    }
  }

  Future<void> _openAdminPanel() async {
    await Navigator.of(context).push(buildAdminPanelRoute());
    if (!mounted) return;
    _loadInstituteLogo();
    _loadWelcomeSettings();
    _loadNews();
  }

  void _startStreamingText(String fullText) {
    _streamingTimer?.cancel();
    _streamingAnswer = '';
    _showAnswerMedia = false;
    _isStreaming = true;
    _streamStartTime = DateTime.now();
    _streamDuration = Duration(
      milliseconds: (fullText.length * 22).clamp(900, 12000),
    );

    void tick() {
      if (!mounted) return;

      final elapsed = DateTime.now().difference(_streamStartTime!);
      final progress = Curves.easeOutCubic.transform(
        (elapsed.inMilliseconds / _streamDuration.inMilliseconds).clamp(
          0.0,
          1.0,
        ),
      );
      final targetLength = (fullText.length * progress).round();

      if (targetLength >= fullText.length) {
        setState(() {
          _streamingAnswer = fullText;
          _isStreaming = false;
          _showAnswerMedia =
              _answerImages.isNotEmpty || _answerVideos.isNotEmpty;
        });
        _scrollToBottomIfNeeded();
        return;
      }

      final nextText = fullText.substring(0, targetLength);
      if (nextText != _streamingAnswer) {
        setState(() => _streamingAnswer = nextText);
        _scrollToBottomIfNeeded();
      }

      _streamingTimer = Timer(const Duration(milliseconds: 16), tick);
    }

    tick();
  }

  void _scrollToBottomIfNeeded() {
    if (!_autoScrollEnabled) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_autoScrollEnabled || !_scrollController.hasClients) return;

      final position = _scrollController.position;
      _scrollController.animateTo(
        position.maxScrollExtent,
        duration: Duration(milliseconds: _isStreaming ? 280 : 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  bool _handleUserScroll(ScrollNotification notification) {
    if (notification is UserScrollNotification &&
        notification.direction != ScrollDirection.idle) {
      if (_autoScrollEnabled) {
        setState(() => _autoScrollEnabled = false);
      }
    }
    return false;
  }

  void _disableAutoScrollOnUserInput() {
    if (_autoScrollEnabled) {
      setState(() => _autoScrollEnabled = false);
    }
  }

  Future<void> _processSearch() async {
    await _runSearch(_controller.text.trim(), articlePreview: null);
  }

  Future<void> _openNewsItem(NewsItem item) async {
    final query = item.text.trim();
    if (query.isEmpty) return;
    await _runSearch(query, articlePreview: item.preview);
  }

  Future<void> _runSearch(String question, {String? articlePreview}) async {
    if (_isServerStarting) return;
    if (question.isEmpty) return;

    setState(() {
      _currentQuestion = question.length > 120
          ? '${question.substring(0, 120).trim()}...'
          : question;
      _hasSearched = true;
      _isLoading = true;
      _isStreaming = false;
      _streamingAnswer = '';
      _answerImages = [];
      _answerVideos = [];
      _showAnswerMedia = false;
      _articlePreviewImage = articlePreview;
      _autoScrollEnabled = true;
    });
    _controller.clear();
    _searchFocus.unfocus();
    _scrollToBottomIfNeeded();

    try {
      await _serverService.ensureRunning();
      final result = await _searchService.search(question);
      final coreDir = AiCorePaths.resolveDbDirectory()?.path;

      setState(() {
        _isLoading = false;
        _answerImages = result.images;
        _answerVideos = result.videos;
        _aiCoreDirectory = coreDir;
      });

      _startStreamingText(result.answer);
      _scrollToBottomIfNeeded();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _streamingAnswer = 'Gözleg ulgamy işlemedi. Ýalňyşlyk: $e';
      });
      _scrollToBottomIfNeeded();
    }
  }

  void _resetSearch() {
    _streamingTimer?.cancel();
    setState(() {
      _hasSearched = false;
      _isStreaming = false;
      _streamingAnswer = '';
      _currentQuestion = '';
      _answerImages = [];
      _answerVideos = [];
      _showAnswerMedia = false;
      _aiCoreDirectory = null;
      _articlePreviewImage = null;
      _autoScrollEnabled = true;
    });
  }

  void _openImageFullscreen(File imageFile) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => FullscreenImagePage(imageFile: imageFile),
      ),
    );
  }

  File? _resolveImageFile(String imageName) {
    return AiCorePaths.resolveImageFile(
      imageName,
      coreDirectory: _aiCoreDirectory,
    );
  }

  File? _resolveVideoFile(String videoName) {
    return AiCorePaths.resolveVideoFile(
      videoName,
      coreDirectory: _aiCoreDirectory,
    );
  }

  @override
  void dispose() {
    _streamingTimer?.cancel();
    _scrollController.dispose();
    _controller.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final searchEnabled = !_isServerStarting;

    return Scaffold(
      backgroundColor: colors.surface,
      body: Stack(
        children: [
          BackgroundGlow(isDark: isDark, colors: colors),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      if (_hasSearched)
                        IconButton(
                          onPressed: _resetSearch,
                          icon: const Icon(Icons.arrow_back_rounded),
                          tooltip: 'Baş sahypa',
                          style: IconButton.styleFrom(
                            foregroundColor: colors.onSurface,
                          ),
                        )
                      else
                        const SizedBox(width: 8),
                      const Spacer(),
                    ],
                  ),
                ),
                Expanded(
                  child: _hasSearched
                      ? _buildResultsLayout(colors, textTheme, searchEnabled)
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final hasNews = _newsItems.isNotEmpty;
                            final newsWidth = NewsCarousel.preferredWidth(
                              constraints.maxWidth,
                            );
                            final newsCardHeight =
                                NewsCarousel.preferredCardHeight(
                              constraints.maxHeight,
                            );

                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Align(
                                  alignment: Alignment.topCenter,
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.fromLTRB(
                                      24,
                                      12,
                                      24,
                                      96,
                                    ),
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 720,
                                      ),
                                      child: WelcomeScreen(
                                        colors: colors,
                                        settings: _welcomeSettings,
                                        controller: _controller,
                                        focusNode: _searchFocus,
                                        enabled: searchEnabled,
                                        instituteLogo: _instituteLogo,
                                        onSearch: _processSearch,
                                        onQuickTag: (tag) {
                                          _controller.text = tag;
                                          _processSearch();
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                if (hasNews)
                                  Positioned(
                                    top: 0,
                                    right: 12,
                                    child: NewsCarousel(
                                      items: _newsItems,
                                      onItemTap: _openNewsItem,
                                      width: newsWidth,
                                      cardHeight: newsCardHeight,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          if (_isServerStarting) _buildServerOverlay(colors, starting: true),
          if (_serverError != null)
            _buildServerOverlay(colors, starting: false, error: _serverError),
          DeveloperFooter(onLongPress: _openAdminPanel),
        ],
      ),
    );
  }

  Widget _buildServerOverlay(
    ColorScheme colors, {
    required bool starting,
    String? error,
  }) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.45),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (starting)
                    CircularProgressIndicator(
                      color: colors.primary,
                      strokeWidth: 6.0,
                    )
                  else
                    Icon(Icons.error_outline, color: colors.error, size: 36),
                  const SizedBox(height: 20),
                  Text(
                    starting
                        ? 'AI serweri başladylýar...'
                        : 'AI serweri işe başlap bilmedi:\n$error',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (!starting) ...[
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _isServerStarting = true;
                          _serverError = null;
                        });
                        _bootstrapServer();
                      },
                      child: const Text('Täzeden synanyş'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsLayout(
    ColorScheme colors,
    TextTheme textTheme,
    bool searchEnabled,
  ) {
    final isDark = colors.brightness == Brightness.dark;

    return Column(
      children: [
        Expanded(
          child: Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                _disableAutoScrollOnUserInput();
              }
            },
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleUserScroll,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: UserBubble(
                            text: _currentQuestion,
                            colors: colors,
                          ),
                        ),
                        const SizedBox(height: 36),
                        Align(
                          alignment: Alignment.center,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 640),
                            child: _isLoading
                                ? ParagraphShimmer(isDark: isDark)
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (_articlePreviewImage != null)
                                        _buildArticleHero(
                                          colors,
                                          isDark,
                                        ),
                                      StreamingAnswerText(
                                        text: _streamingAnswer,
                                        isStreaming: _isStreaming,
                                        textStyle: textTheme.bodyLarge!,
                                        cursorColor: colors.primary,
                                      ),
                                      if (_showAnswerMedia &&
                                          _answerImages.isNotEmpty)
                                        AnswerImagesReveal(
                                          child: AnswerImagesRow(
                                            imageNames: _answerImages,
                                            colors: colors,
                                            resolveImage: _resolveImageFile,
                                            onImageTap: _openImageFullscreen,
                                          ),
                                        ),
                                      if (_showAnswerMedia &&
                                          _answerVideos.isNotEmpty)
                                        AnswerImagesReveal(
                                          child: AnswerVideosRow(
                                            videoNames: _answerVideos,
                                            colors: colors,
                                            resolveVideo: _resolveVideoFile,
                                          ),
                                        ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 72),
          child: Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: SearchBarField(
                controller: _controller,
                focusNode: _searchFocus,
                colors: colors,
                enabled: searchEnabled,
                onSubmitted: _processSearch,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildArticleHero(ColorScheme colors, bool isDark) {
    final previewFile = _resolveImageFile(_articlePreviewImage!);
    if (previewFile == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openImageFullscreen(previewFile),
            child: Ink(
              decoration: BoxDecoration(
                gradient: isDark
                    ? AppPalette.darkQuickTag
                    : AppPalette.lightQuickTag,
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF3C4043)
                      : AppPalette.lightGreenBorder,
                ),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 420,
                  maxHeight: 280,
                ),
                child: Image.file(
                  previewFile,
                  fit: BoxFit.scaleDown,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
