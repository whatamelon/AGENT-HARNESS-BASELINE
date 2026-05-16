/**
 * Mobile design harness — Expo Web iPhone 17 Pro Max preview shell.
 *
 * Use in comparison/prototype Expo apps only. Production mobile apps should use the
 * real device SafeAreaProvider without a browser mock shell.
 */
import type { ReactNode } from "react";
import { Platform, StyleSheet, useWindowDimensions, View, type ViewStyle } from "react-native";
import { SafeAreaFrameContext, SafeAreaInsetsContext, SafeAreaProvider, type Metrics } from "react-native-safe-area-context";

const IPHONE_17_PRO_MAX = {
  screenW: 440,
  screenH: 956,
  bezel: 2,
  shellRadius: 58,
  screenRadius: 56,
  islandW: 124,
  islandH: 36,
  islandTop: 17,
  camera: 12,
  homeW: 134,
  safeTop: 59,
  safeBottom: 34,
} as const;

const previewMetrics: Metrics = {
  frame: { x: 0, y: 0, width: IPHONE_17_PRO_MAX.screenW, height: IPHONE_17_PRO_MAX.screenH },
  insets: { top: IPHONE_17_PRO_MAX.safeTop, right: 0, bottom: IPHONE_17_PRO_MAX.safeBottom, left: 0 },
};

/** iPhone 17 Pro Max preview shell for design comparison harnesses. */
export function Iphone17ProMaxDesignHarness({ children }: { children: ReactNode }) {
  const viewport = useWindowDimensions();
  if (Platform.OS !== "web") return <SafeAreaProvider>{children}</SafeAreaProvider>;

  const shellBaseW = IPHONE_17_PRO_MAX.screenW + IPHONE_17_PRO_MAX.bezel * 2;
  const shellBaseH = IPHONE_17_PRO_MAX.screenH + IPHONE_17_PRO_MAX.bezel * 2;
  const safeGap = 48;
  const scale = Math.min(1, (viewport.width - safeGap) / shellBaseW, (viewport.height - safeGap) / shellBaseH);
  const s = Number.isFinite(scale) && scale > 0 ? scale : 1;

  return (
    <View style={[styles.desktopCanvas, { minHeight: viewport.height }]}>
      <View
        style={[
          styles.phoneShell,
          webShadow,
          {
            width: shellBaseW * s,
            height: shellBaseH * s,
            borderRadius: IPHONE_17_PRO_MAX.shellRadius * s,
            padding: IPHONE_17_PRO_MAX.bezel * s,
          },
        ]}
      >
        <View style={[styles.actionButton, { top: 142 * s, height: 38 * s }]} />
        <View style={[styles.volumeButton, { top: 214 * s, height: 66 * s }]} />
        <View style={[styles.volumeButton, { top: 298 * s, height: 66 * s }]} />
        <View style={[styles.sideButtonRight, { top: 238 * s, height: 104 * s }]} />
        <View style={[styles.screenClip, { borderRadius: IPHONE_17_PRO_MAX.screenRadius * s }]}>
          <SafeAreaFrameContext.Provider value={previewMetrics.frame}>
            <SafeAreaInsetsContext.Provider value={previewMetrics.insets}>{children}</SafeAreaInsetsContext.Provider>
          </SafeAreaFrameContext.Provider>
          <View
            pointerEvents="none"
            style={[
              styles.dynamicIsland,
              {
                top: IPHONE_17_PRO_MAX.islandTop * s,
                width: IPHONE_17_PRO_MAX.islandW * s,
                height: IPHONE_17_PRO_MAX.islandH * s,
                marginLeft: -(IPHONE_17_PRO_MAX.islandW * s) / 2,
                borderRadius: (IPHONE_17_PRO_MAX.islandH * s) / 2,
                paddingRight: 12 * s,
              },
            ]}
          >
            <View
              style={[
                styles.islandCamera,
                { width: IPHONE_17_PRO_MAX.camera * s, height: IPHONE_17_PRO_MAX.camera * s, borderRadius: (IPHONE_17_PRO_MAX.camera * s) / 2 },
              ]}
            />
          </View>
          <View pointerEvents="none" style={[styles.homeIndicator, { width: IPHONE_17_PRO_MAX.homeW * s, marginLeft: -(IPHONE_17_PRO_MAX.homeW * s) / 2 }]} />
        </View>
      </View>
    </View>
  );
}

const webShadow: ViewStyle = Platform.OS === "web" ? ({ boxShadow: "0 24px 80px rgba(0,0,0,0.18)" } as ViewStyle) : {};

const styles = StyleSheet.create({
  desktopCanvas: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#F3F4F1",
    padding: 24,
    overflow: "hidden",
  },
  phoneShell: {
    backgroundColor: "#0E0E0E",
    position: "relative",
  },
  screenClip: {
    flex: 1,
    overflow: "hidden",
    backgroundColor: "#FFFFFF",
  },
  dynamicIsland: {
    position: "absolute",
    left: "50%",
    backgroundColor: "#050505",
    alignItems: "flex-end",
    justifyContent: "center",
  },
  islandCamera: {
    backgroundColor: "#161616",
    borderWidth: 1,
    borderColor: "#242424",
  },
  homeIndicator: {
    position: "absolute",
    bottom: 8,
    left: "50%",
    height: 4,
    borderRadius: 999,
    backgroundColor: "#2E2E2E",
  },
  actionButton: {
    position: "absolute",
    left: -2,
    width: 2,
    borderRadius: 999,
    backgroundColor: "#2B2B2B",
  },
  volumeButton: {
    position: "absolute",
    left: -2,
    width: 2,
    borderRadius: 999,
    backgroundColor: "#2B2B2B",
  },
  sideButtonRight: {
    position: "absolute",
    right: -2,
    width: 2,
    borderRadius: 999,
    backgroundColor: "#2B2B2B",
  },
});
