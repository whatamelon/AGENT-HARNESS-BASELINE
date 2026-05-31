/// ANDS v2.0 design system: tokens, theme, adaptive primary, and the P1-a
/// component set. Light mode only (ThemeMode.light).
///
/// Layout of exports:
/// - Generated tokens (committed; regenerate via tool/gen_tokens.dart).
/// - Adaptive primary color engine.
/// - Theme builder + DsColors ThemeExtension.
/// - P1-a components: Button, TextField, Card, AppBar.
/// - P1.5 Batch A: List, Chip/Badge/Tag, BottomSheet, StateView.
/// - P1.5 Batch B: BottomNav, Image, Dialog, Snackbar.
library;

export 'src/color/adaptive_primary.dart' show AdaptivePrimary, contrastRatio;
export 'src/components/app_bar.dart' show DsAppBar;
export 'src/components/bottom_nav.dart' show DsBottomNav, DsNavItem;
export 'src/components/bottom_sheet.dart' show DsBottomSheet, showDsBottomSheet;
export 'src/components/button.dart' show DsButton, DsButtonVariant;
export 'src/components/card.dart' show DsCard, DsCardVariant;
export 'src/components/chip.dart'
    show DsBadge, DsBadgeTone, DsChip, DsCountBadge, DsTag;
export 'src/components/dialog.dart'
    show DsDialog, DsDialogVariant, showDsDialog;
export 'src/components/image.dart' show DsImage;
export 'src/components/list.dart' show DsList, DsListItem, DsListStatus;
export 'src/components/snackbar.dart'
    show DsSnackTone, DsSnackbarContent, buildDsSnackBar, showDsSnackbar;
export 'src/components/state_view.dart' show DsStateVariant, DsStateView;
export 'src/components/text_field.dart' show DsFieldStatus, DsTextField;
export 'src/gen/colors.dart' show DsPrimitive;
export 'src/gen/dimens.dart' show DsState, Radii, Space;
export 'src/gen/elevation.dart' show Elevation;
export 'src/gen/motion.dart' show Motion;
export 'src/gen/typography.dart' show DsType;
export 'src/theme/app_theme.dart' show buildTheme;
export 'src/theme/ds_colors.dart' show DsColors, DsColorsContext;
