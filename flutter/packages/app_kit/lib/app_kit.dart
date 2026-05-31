/// App shell: go_router `StatefulShellRoute` + a single `ChromeController`
/// (route policy + scroll show/hide) layered over `core` and `ds`.
///
/// The package is app-agnostic: tab branches and the route -> chrome policy
/// registry are injected by each app (park != onyu). The shell subscribes only
/// to `authStateProvider` from `core` (the §8-B one-way boundary) and never
/// touches the auth or network implementation.
library;

export 'src/analytics/analytics_wiring.dart' show FirebaseAnalyticsSink;
export 'src/auth/account_deletion.dart'
    show
        AccountDeletionClient,
        AccountDeletionError,
        AccountDeletionFailure,
        accountDeletionFailureMessage,
        kAccountDeletePath;
export 'src/auth/auth_ports.dart'
    show
        AppleCredentialPort,
        GoTrueAuthPort,
        IdTokenCredential,
        KakaoLoginPort;
export 'src/auth/auth_wiring.dart'
    show
        KakaoLoginAdapter,
        SignInWithApplePort,
        SupabaseGoTruePort,
        SupabaseSessionBootstrap,
        initSupabaseSecure;
export 'src/auth/biometric/biometric_port.dart'
    show BiometricGate, BiometricPort, BiometricResult;
export 'src/auth/biometric/biometric_wiring.dart' show LocalAuthBiometricPort;
export 'src/auth/secure_session_storage.dart'
    show
        FlutterSecureKeyValueStore,
        SecureGotrueAsyncStorage,
        SecureKeyValueStore,
        SecureSessionStorage;
export 'src/auth/sms/sms_auth_client.dart'
    show
        SmsAuthClient,
        SmsError,
        SmsFailure,
        SmsRequestResult,
        normalizeKrMobile,
        smsFailureMessage;
export 'src/auth/social/apple_auth.dart' show AppleAuthService;
export 'src/auth/social/kakao_auth.dart' show KakaoAuthService;
export 'src/auth/supabase_auth_controller.dart'
    show AuthBreadcrumb, SupabaseAuthController, sessionExpiredProvider;
export 'src/chrome/chrome_controller.dart'
    show
        ChromeController,
        ChromeState,
        chromeControllerProvider,
        defaultChromeControllerProvider;
export 'src/chrome/route_chrome_policy.dart'
    show
        ChromePolicyResolver,
        DsAppBarStyle,
        RouteChromePolicy,
        defaultChromePolicyResolver;
export 'src/deeplink/deep_link_service.dart'
    show AppLinksPort, DeepLinkService, NavigateToWhitelistedRoute;
export 'src/deeplink/install_referrer.dart'
    show
        InstallReferrerHandler,
        InstallReferrerReader,
        NoopInstallReferrerReader;
export 'src/deeplink/link_resolver.dart' show LinkResolver, kLinkResolvePath;
export 'src/deeplink/link_wiring.dart' show AppLinksAdapter;
export 'src/deeplink/route_whitelist.dart' show ResolvedRoute, RouteWhitelist;
export 'src/domain_state/collection_repository.dart' show CollectionRepository;
export 'src/domain_state/derived_counts.dart'
    show
        collectionCountProvider,
        collectionDistinctCountProvider,
        collectionReduceProvider;
export 'src/domain_state/guest_collection_store.dart' show GuestCollectionStore;
export 'src/domain_state/reactive_collection.dart'
    show
        CollectionSnapshot,
        KeyedCollectionController,
        concurrentWriteConflict,
        kConcurrentWriteStatus;
export 'src/nav/branch_aware_back_scope.dart'
    show BranchAwareBackScope, UnsavedGuard;
export 'src/nav/list_view_state.dart'
    show ListViewState, ListViewStateNotifier, listViewStateProvider;
export 'src/network/auth_refresh_interceptor.dart'
    show
        AuthRefreshInterceptor,
        CurrentToken,
        OnUnrecoverable,
        RefreshSession,
        kRetriedExtraKey;
export 'src/payments/billing_backend.dart'
    show
        BillingAuthFailure,
        BillingAuthRequest,
        BillingAuthResult,
        BillingAuthSuccess,
        BillingBackend;
export 'src/payments/billing_service.dart'
    show
        BillingError,
        BillingMandate,
        BillingService,
        RequestBillingAuth,
        billingErrorMessage,
        kBillingCancelPath,
        kBillingRegisterPath;
export 'src/payments/billing_wiring.dart'
    show TossBillingAuthFlow, TossBillingBackend;
export 'src/payments/payment_backend.dart'
    show
        PaymentAmount,
        PaymentBackend,
        PaymentBackendFailure,
        PaymentBackendPending,
        PaymentBackendResult,
        PaymentBackendSuccess,
        PaymentCurrency,
        PaymentRequest;
export 'src/payments/payment_controller.dart'
    show
        PaymentController,
        PaymentPhase,
        PaymentState,
        paymentControllerProvider;
export 'src/payments/payment_service.dart'
    show
        PaymentConfirmation,
        PaymentError,
        PaymentOrder,
        PaymentService,
        RenderAndRequest,
        kPaymentConfirmPath,
        kPaymentCreateOrderPath,
        paymentErrorMessage;
export 'src/payments/payment_webview_policy.dart' show PaymentWebViewPolicy;
export 'src/payments/payment_widget_host.dart' show PaymentWidgetHost;
export 'src/payments/payment_wiring.dart'
    show TossPaymentBackend, buildTossPaymentWidget;
export 'src/push/device_token_registrar.dart'
    show DevicePlatform, DeviceTokenRegistrar, DeviceTokenStore;
export 'src/push/local_notifications.dart'
    show LocalNotifications, kDefaultChannelId;
export 'src/push/push_backend.dart'
    show
        LocalNotificationPort,
        PushBackend,
        PushMessage,
        PushPermission;
export 'src/push/push_service.dart'
    show
        ForegroundDisplayGate,
        NavigateToRoute,
        PrePromptGate,
        PushService;
export 'src/push/push_wiring.dart'
    show
        FirebasePushBackend,
        SupabaseDeviceTokenStore,
        firebaseMessagingBackgroundHandler,
        initFirebaseMessaging;
export 'src/realtime/live_subscription.dart'
    show LiveConnectionState, LiveState, LiveSubscriptionController;
export 'src/router/app_router.dart' show RootRoutesBuilder, buildAppRouter;
export 'src/router/route_policy.dart'
    show RouteAuthLevel, RouteAuthLevelResolver, RouteAuthPolicy;
export 'src/router/splash_gate.dart' show SplashScreen;
export 'src/scroll/chrome_scroll.dart' show ChromeScroll;
export 'src/shell/app_shell.dart' show AppShell;
export 'src/shell/shell_branch.dart' show ShellBranch;
