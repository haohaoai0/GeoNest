import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const PREF_STORE: string = 'geonest_store';

export const APP_THEME_MODE_KEY: string = 'gnThemeMode';
export const APP_MATERIAL_QUALITY_KEY: string = 'gnMaterialQuality';
export const APP_INTERFACE_DENSITY_KEY: string = 'gnInterfaceDensity';
export const APP_STARTUP_ANIMATION_KEY: string = 'gnStartupAnimationEnabled';
export const APP_OPEN_SIDE_PANES_KEY: string = 'gnOpenSidePanesOnStartup';
export const APP_MATERIAL_ENABLED_KEY: string = 'gnMaterialEnabled';
export const APP_MAP_RENDER_QUALITY_KEY: string = 'gnMapRenderQuality';
export const APP_FRAME_PACING_KEY: string = 'gnFramePacing';
export const APP_CACHE_STRATEGY_KEY: string = 'gnCacheStrategy';
export const APP_PROGRESSIVE_LOADING_KEY: string = 'gnProgressiveLoading';
export const APP_POINTER_SMOOTHING_KEY: string = 'gnPointerSmoothing';
export const APP_REDUCED_MOTION_KEY: string = 'gnReducedMotion';
export const APP_FLOATING_TAB_MATERIAL_KEY: string = 'gnFloatingTabMaterial';
export const APP_MOUSE_SCROLL_OPTIMIZATION_KEY: string = 'gnMouseScrollOptimization';

export const THEME_MODE_SYSTEM: number = 0;
export const THEME_MODE_LIGHT: number = 1;
export const THEME_MODE_DARK: number = 2;

export const MATERIAL_QUALITY_EFFICIENT: number = 0;
export const MATERIAL_QUALITY_BALANCED: number = 1;
export const MATERIAL_QUALITY_REFINED: number = 2;

export const INTERFACE_DENSITY_AUTO: number = 0;
export const INTERFACE_DENSITY_COMPACT: number = 1;
export const INTERFACE_DENSITY_COMFORTABLE: number = 2;

export const MAP_RENDER_QUALITY_EFFICIENT: number = 0;
export const MAP_RENDER_QUALITY_BALANCED: number = 1;
export const MAP_RENDER_QUALITY_REFINED: number = 2;

export const FRAME_PACING_POWER_SAVE: number = 0;
export const FRAME_PACING_BALANCED: number = 1;
export const FRAME_PACING_HIGH: number = 2;

export const CACHE_STRATEGY_CONSERVATIVE: number = 0;
export const CACHE_STRATEGY_BALANCED: number = 1;
export const CACHE_STRATEGY_AGGRESSIVE: number = 2;

export const DEFAULT_STARTUP_ANIMATION_ENABLED: boolean = true;
export const DEFAULT_OPEN_SIDE_PANES: boolean = true;
export const DEFAULT_MATERIAL_ENABLED: boolean = true;
export const DEFAULT_PROGRESSIVE_LOADING: boolean = true;
export const DEFAULT_POINTER_SMOOTHING: boolean = true;
export const DEFAULT_REDUCED_MOTION: boolean = false;
export const DEFAULT_FLOATING_TAB_MATERIAL: boolean = true;
export const DEFAULT_MOUSE_SCROLL_OPTIMIZATION: boolean = true;

function readBool(prefs: preferences.Preferences, key: string, def: boolean): boolean {
  return prefs.getSync(key, def) as boolean;
}

function readNum(prefs: preferences.Preferences, key: string, def: number): number {
  return prefs.getSync(key, def) as number;
}

export function initPreferences(context: common.UIAbilityContext): void {
  try {
    const prefs: preferences.Preferences = preferences.getPreferencesSync(context, { name: PREF_STORE });
    AppStorage.setOrCreate(APP_THEME_MODE_KEY, readNum(prefs, APP_THEME_MODE_KEY, THEME_MODE_SYSTEM));
    AppStorage.setOrCreate(APP_MATERIAL_QUALITY_KEY, readNum(prefs, APP_MATERIAL_QUALITY_KEY, MATERIAL_QUALITY_BALANCED));
    AppStorage.setOrCreate(APP_INTERFACE_DENSITY_KEY, readNum(prefs, APP_INTERFACE_DENSITY_KEY, INTERFACE_DENSITY_AUTO));
    AppStorage.setOrCreate(APP_STARTUP_ANIMATION_KEY, readBool(prefs, APP_STARTUP_ANIMATION_KEY, DEFAULT_STARTUP_ANIMATION_ENABLED));
    AppStorage.setOrCreate(APP_OPEN_SIDE_PANES_KEY, readBool(prefs, APP_OPEN_SIDE_PANES_KEY, DEFAULT_OPEN_SIDE_PANES));
    AppStorage.setOrCreate(APP_MATERIAL_ENABLED_KEY, readBool(prefs, APP_MATERIAL_ENABLED_KEY, DEFAULT_MATERIAL_ENABLED));
    AppStorage.setOrCreate(APP_MAP_RENDER_QUALITY_KEY, readNum(prefs, APP_MAP_RENDER_QUALITY_KEY, MAP_RENDER_QUALITY_BALANCED));
    AppStorage.setOrCreate(APP_FRAME_PACING_KEY, readNum(prefs, APP_FRAME_PACING_KEY, FRAME_PACING_BALANCED));
    AppStorage.setOrCreate(APP_CACHE_STRATEGY_KEY, readNum(prefs, APP_CACHE_STRATEGY_KEY, CACHE_STRATEGY_BALANCED));
    AppStorage.setOrCreate(APP_PROGRESSIVE_LOADING_KEY, readBool(prefs, APP_PROGRESSIVE_LOADING_KEY, DEFAULT_PROGRESSIVE_LOADING));
    AppStorage.setOrCreate(APP_POINTER_SMOOTHING_KEY, readBool(prefs, APP_POINTER_SMOOTHING_KEY, DEFAULT_POINTER_SMOOTHING));
    AppStorage.setOrCreate(APP_REDUCED_MOTION_KEY, readBool(prefs, APP_REDUCED_MOTION_KEY, DEFAULT_REDUCED_MOTION));
    AppStorage.setOrCreate(APP_FLOATING_TAB_MATERIAL_KEY, readBool(prefs, APP_FLOATING_TAB_MATERIAL_KEY, DEFAULT_FLOATING_TAB_MATERIAL));
    AppStorage.setOrCreate(APP_MOUSE_SCROLL_OPTIMIZATION_KEY, readBool(prefs, APP_MOUSE_SCROLL_OPTIMIZATION_KEY, DEFAULT_MOUSE_SCROLL_OPTIMIZATION));
  } catch (e) {
    AppStorage.setOrCreate(APP_THEME_MODE_KEY, THEME_MODE_SYSTEM);
    AppStorage.setOrCreate(APP_MATERIAL_QUALITY_KEY, MATERIAL_QUALITY_BALANCED);
    AppStorage.setOrCreate(APP_INTERFACE_DENSITY_KEY, INTERFACE_DENSITY_AUTO);
    AppStorage.setOrCreate(APP_STARTUP_ANIMATION_KEY, DEFAULT_STARTUP_ANIMATION_ENABLED);
    AppStorage.setOrCreate(APP_OPEN_SIDE_PANES_KEY, DEFAULT_OPEN_SIDE_PANES);
    AppStorage.setOrCreate(APP_MATERIAL_ENABLED_KEY, DEFAULT_MATERIAL_ENABLED);
    AppStorage.setOrCreate(APP_MAP_RENDER_QUALITY_KEY, MAP_RENDER_QUALITY_BALANCED);
    AppStorage.setOrCreate(APP_FRAME_PACING_KEY, FRAME_PACING_BALANCED);
    AppStorage.setOrCreate(APP_CACHE_STRATEGY_KEY, CACHE_STRATEGY_BALANCED);
    AppStorage.setOrCreate(APP_PROGRESSIVE_LOADING_KEY, DEFAULT_PROGRESSIVE_LOADING);
    AppStorage.setOrCreate(APP_POINTER_SMOOTHING_KEY, DEFAULT_POINTER_SMOOTHING);
    AppStorage.setOrCreate(APP_REDUCED_MOTION_KEY, DEFAULT_REDUCED_MOTION);
    AppStorage.setOrCreate(APP_FLOATING_TAB_MATERIAL_KEY, DEFAULT_FLOATING_TAB_MATERIAL);
    AppStorage.setOrCreate(APP_MOUSE_SCROLL_OPTIMIZATION_KEY, DEFAULT_MOUSE_SCROLL_OPTIMIZATION);
  }
}

export function savePreferences(context: common.UIAbilityContext): void {
  try {
    const prefs: preferences.Preferences = preferences.getPreferencesSync(context, { name: PREF_STORE });
    prefs.putSync(APP_THEME_MODE_KEY, AppStorage.get<number>(APP_THEME_MODE_KEY) ?? THEME_MODE_SYSTEM);
    prefs.putSync(APP_MATERIAL_QUALITY_KEY, AppStorage.get<number>(APP_MATERIAL_QUALITY_KEY) ?? MATERIAL_QUALITY_BALANCED);
    prefs.putSync(APP_INTERFACE_DENSITY_KEY, AppStorage.get<number>(APP_INTERFACE_DENSITY_KEY) ?? INTERFACE_DENSITY_AUTO);
    prefs.putSync(APP_STARTUP_ANIMATION_KEY, AppStorage.get<boolean>(APP_STARTUP_ANIMATION_KEY) ?? DEFAULT_STARTUP_ANIMATION_ENABLED);
    prefs.putSync(APP_OPEN_SIDE_PANES_KEY, AppStorage.get<boolean>(APP_OPEN_SIDE_PANES_KEY) ?? DEFAULT_OPEN_SIDE_PANES);
    prefs.putSync(APP_MATERIAL_ENABLED_KEY, AppStorage.get<boolean>(APP_MATERIAL_ENABLED_KEY) ?? DEFAULT_MATERIAL_ENABLED);
    prefs.putSync(APP_MAP_RENDER_QUALITY_KEY, AppStorage.get<number>(APP_MAP_RENDER_QUALITY_KEY) ?? MAP_RENDER_QUALITY_BALANCED);
    prefs.putSync(APP_FRAME_PACING_KEY, AppStorage.get<number>(APP_FRAME_PACING_KEY) ?? FRAME_PACING_BALANCED);
    prefs.putSync(APP_CACHE_STRATEGY_KEY, AppStorage.get<number>(APP_CACHE_STRATEGY_KEY) ?? CACHE_STRATEGY_BALANCED);
    prefs.putSync(APP_PROGRESSIVE_LOADING_KEY, AppStorage.get<boolean>(APP_PROGRESSIVE_LOADING_KEY) ?? DEFAULT_PROGRESSIVE_LOADING);
    prefs.putSync(APP_POINTER_SMOOTHING_KEY, AppStorage.get<boolean>(APP_POINTER_SMOOTHING_KEY) ?? DEFAULT_POINTER_SMOOTHING);
    prefs.putSync(APP_REDUCED_MOTION_KEY, AppStorage.get<boolean>(APP_REDUCED_MOTION_KEY) ?? DEFAULT_REDUCED_MOTION);
    prefs.putSync(APP_FLOATING_TAB_MATERIAL_KEY, AppStorage.get<boolean>(APP_FLOATING_TAB_MATERIAL_KEY) ?? DEFAULT_FLOATING_TAB_MATERIAL);
    prefs.putSync(APP_MOUSE_SCROLL_OPTIMIZATION_KEY, AppStorage.get<boolean>(APP_MOUSE_SCROLL_OPTIMIZATION_KEY) ?? DEFAULT_MOUSE_SCROLL_OPTIMIZATION);
    prefs.flush();
  } catch (e) {
    // silent fail
  }
}
