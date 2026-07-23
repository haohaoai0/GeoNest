import { application, ConfigurationConstant } from '@kit.AbilityKit';
import { HdsNavigation, HdsNavigationTitleMode, IconStyleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { hdsMaterial } from '@hms.hds.hdsMaterial';
import { MaterialStyle } from '@geonest/common';
import {
  APP_CACHE_STRATEGY_KEY,
  APP_FLOATING_TAB_MATERIAL_KEY,
  APP_FRAME_PACING_KEY,
  APP_INTERFACE_DENSITY_KEY,
  APP_MAP_RENDER_QUALITY_KEY,
  APP_MATERIAL_ENABLED_KEY,
  APP_MATERIAL_QUALITY_KEY,
  APP_MOUSE_SCROLL_OPTIMIZATION_KEY,
  APP_OPEN_SIDE_PANES_KEY,
  APP_POINTER_SMOOTHING_KEY,
  APP_PROCESSING_AUTO_LOAD_OUTPUT_KEY,
  APP_PROCESSING_HISTORY_LIMIT_KEY,
  APP_PROCESSING_KEEP_HISTORY_KEY,
  APP_PROCESSING_OUTPUT_FOLDER_KEY,
  APP_PROCESSING_OVERWRITE_OUTPUT_KEY,
  APP_PROGRESSIVE_LOADING_KEY,
  APP_REDUCED_MOTION_KEY,
  APP_STARTUP_ANIMATION_KEY,
  APP_THEME_MODE_KEY,
  CACHE_STRATEGY_AGGRESSIVE,
  CACHE_STRATEGY_BALANCED,
  CACHE_STRATEGY_CONSERVATIVE,
  DEFAULT_FLOATING_TAB_MATERIAL,
  DEFAULT_MATERIAL_ENABLED,
  DEFAULT_MOUSE_SCROLL_OPTIMIZATION,
  DEFAULT_OPEN_SIDE_PANES,
  DEFAULT_POINTER_SMOOTHING,
  DEFAULT_PROCESSING_AUTO_LOAD_OUTPUT,
  DEFAULT_PROCESSING_HISTORY_LIMIT,
  DEFAULT_PROCESSING_KEEP_HISTORY,
  DEFAULT_PROCESSING_OUTPUT_FOLDER,
  DEFAULT_PROCESSING_OVERWRITE_OUTPUT,
  DEFAULT_PROGRESSIVE_LOADING,
  DEFAULT_REDUCED_MOTION,
  DEFAULT_STARTUP_ANIMATION_ENABLED,
  FRAME_PACING_BALANCED,
  FRAME_PACING_HIGH,
  FRAME_PACING_POWER_SAVE,
  INTERFACE_DENSITY_AUTO,
  INTERFACE_DENSITY_COMFORTABLE,
  INTERFACE_DENSITY_COMPACT,
  MAP_RENDER_QUALITY_BALANCED,
  MAP_RENDER_QUALITY_EFFICIENT,
  MAP_RENDER_QUALITY_REFINED,
  MATERIAL_QUALITY_BALANCED,
  MATERIAL_QUALITY_EFFICIENT,
  MATERIAL_QUALITY_REFINED,
  THEME_MODE_DARK,
  THEME_MODE_LIGHT,
  THEME_MODE_SYSTEM,
  savePreferences
} from '../model/AppPreferences';
import { common } from '@kit.AbilityKit';

const CATEGORY_APPEARANCE: number = 0;
const CATEGORY_WORKSPACE: number = 1;
const CATEGORY_MAP_PERFORMANCE: number = 2;
const CATEGORY_INPUT: number = 3;
const CATEGORY_ACCESSIBILITY: number = 4;
const CATEGORY_PROCESSING: number = 5;
const CATEGORY_API26: number = 6;

const PROFILE_THEME: number = 0;
const PROFILE_MATERIAL: number = 1;
const PROFILE_DENSITY: number = 2;
const PROFILE_RENDER: number = 3;
const PROFILE_FRAME: number = 4;
const PROFILE_CACHE: number = 5;

const SETTING_STARTUP_ANIMATION: number = 1;
const SETTING_OPEN_SIDE_PANES: number = 2;
const SETTING_IMMERSIVE_MATERIAL: number = 3;
const SETTING_PROGRESSIVE_LOADING: number = 4;
const SETTING_POINTER_SMOOTHING: number = 5;
const SETTING_REDUCED_MOTION: number = 6;
const SETTING_FLOATING_TAB_MATERIAL: number = 7;
const SETTING_MOUSE_SCROLL_OPTIMIZATION: number = 8;
const SETTING_PROCESSING_OVERWRITE_OUTPUT: number = 9;
const SETTING_PROCESSING_AUTO_LOAD_OUTPUT: number = 10;
const SETTING_PROCESSING_KEEP_HISTORY: number = 11;

@Component
export struct AppSettingsSheet {
  @Prop @Watch('onTrigger') trigger: boolean = false;
  @State isShow: boolean = false;
  @State private selectedCategory: number = CATEGORY_APPEARANCE;
  @State private uiRevision: number = 0;
  @StorageLink(APP_THEME_MODE_KEY) private themeMode: number = THEME_MODE_SYSTEM;
  @StorageLink(APP_MATERIAL_QUALITY_KEY) private materialQuality: number = MATERIAL_QUALITY_BALANCED;
  @StorageLink(APP_INTERFACE_DENSITY_KEY) private interfaceDensity: number = INTERFACE_DENSITY_AUTO;
  @StorageLink(APP_MAP_RENDER_QUALITY_KEY) private mapRenderQuality: number = MAP_RENDER_QUALITY_BALANCED;
  @StorageLink(APP_FRAME_PACING_KEY) private framePacing: number = FRAME_PACING_BALANCED;
  @StorageLink(APP_CACHE_STRATEGY_KEY) private cacheStrategy: number = CACHE_STRATEGY_BALANCED;
  @StorageLink(APP_STARTUP_ANIMATION_KEY) private startupAnimationEnabled: boolean =
    DEFAULT_STARTUP_ANIMATION_ENABLED;
  @StorageLink(APP_OPEN_SIDE_PANES_KEY) private openSidePanesOnStartup: boolean = DEFAULT_OPEN_SIDE_PANES;
  @StorageLink(APP_MATERIAL_ENABLED_KEY) private materialEnabled: boolean = DEFAULT_MATERIAL_ENABLED;
  @StorageLink(APP_PROGRESSIVE_LOADING_KEY) private progressiveLoading: boolean = DEFAULT_PROGRESSIVE_LOADING;
  @StorageLink(APP_POINTER_SMOOTHING_KEY) private pointerSmoothing: boolean = DEFAULT_POINTER_SMOOTHING;
  @StorageLink(APP_REDUCED_MOTION_KEY) private reducedMotion: boolean = DEFAULT_REDUCED_MOTION;
  @StorageLink(APP_FLOATING_TAB_MATERIAL_KEY) private floatingTabMaterial: boolean =
    DEFAULT_FLOATING_TAB_MATERIAL;
  @StorageLink(APP_MOUSE_SCROLL_OPTIMIZATION_KEY) private mouseScrollOptimization: boolean =
    DEFAULT_MOUSE_SCROLL_OPTIMIZATION;
  @StorageLink(APP_PROCESSING_OUTPUT_FOLDER_KEY) private processingOutputFolder: string =
    DEFAULT_PROCESSING_OUTPUT_FOLDER;
  @StorageLink(APP_PROCESSING_OVERWRITE_OUTPUT_KEY) private processingOverwriteOutput: boolean =
    DEFAULT_PROCESSING_OVERWRITE_OUTPUT;
  @StorageLink(APP_PROCESSING_AUTO_LOAD_OUTPUT_KEY) private processingAutoLoadOutput: boolean =
    DEFAULT_PROCESSING_AUTO_LOAD_OUTPUT;
  @StorageLink(APP_PROCESSING_KEEP_HISTORY_KEY) private processingKeepHistory: boolean =
    DEFAULT_PROCESSING_KEEP_HISTORY;
  @StorageLink(APP_PROCESSING_HISTORY_LIMIT_KEY) private processingHistoryLimit: number =
    DEFAULT_PROCESSING_HISTORY_LIMIT;
  @State private processingOutputFolderDraft: string = DEFAULT_PROCESSING_OUTPUT_FOLDER;
  private contentScroller: Scroller = new Scroller();

  onTrigger(): void {
    this.processingOutputFolderDraft = this.processingOutputFolder;
    this.isShow = true;
  }

  private refreshUi(): void {
    this.uiRevision++;
  }

  private persist(): void {
    const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    savePreferences(ctx);
  }

  private applyThemeMode(mode: number): void {
    this.themeMode = mode;
    this.refreshUi();
    this.persist();
    try {
      if (mode === THEME_MODE_DARK) {
        application.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
      } else if (mode === THEME_MODE_LIGHT) {
        application.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
      } else {
        application.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      }
    } catch (err) {
      console.error('GeoNest settings failed to apply theme: ' + JSON.stringify(err));
    }
  }

  private profileValue(group: number): number {
    if (group === PROFILE_THEME) {
      return this.themeMode;
    }
    if (group === PROFILE_MATERIAL) {
      return this.materialQuality;
    }
    if (group === PROFILE_DENSITY) {
      return this.interfaceDensity;
    }
    if (group === PROFILE_RENDER) {
      return this.mapRenderQuality;
    }
    if (group === PROFILE_FRAME) {
      return this.framePacing;
    }
    return this.cacheStrategy;
  }

  private setProfile(group: number, value: number): void {
    if (group === PROFILE_THEME) {
      this.applyThemeMode(value);
      return;
    }
    if (group === PROFILE_MATERIAL) {
      this.materialQuality = value;
    } else if (group === PROFILE_DENSITY) {
      this.interfaceDensity = value;
    } else if (group === PROFILE_RENDER) {
      this.mapRenderQuality = value;
    } else if (group === PROFILE_FRAME) {
      this.framePacing = value;
    } else {
      this.cacheStrategy = value;
    }
    this.refreshUi();
    this.persist();
  }

  private booleanSettingValue(settingId: number): boolean {
    if (settingId === SETTING_STARTUP_ANIMATION) {
      return this.startupAnimationEnabled;
    }
    if (settingId === SETTING_OPEN_SIDE_PANES) {
      return this.openSidePanesOnStartup;
    }
    if (settingId === SETTING_IMMERSIVE_MATERIAL) {
      return this.materialEnabled;
    }
    if (settingId === SETTING_PROGRESSIVE_LOADING) {
      return this.progressiveLoading;
    }
    if (settingId === SETTING_POINTER_SMOOTHING) {
      return this.pointerSmoothing;
    }
    if (settingId === SETTING_REDUCED_MOTION) {
      return this.reducedMotion;
    }
    if (settingId === SETTING_FLOATING_TAB_MATERIAL) {
      return this.floatingTabMaterial;
    }
    if (settingId === SETTING_PROCESSING_OVERWRITE_OUTPUT) {
      return this.processingOverwriteOutput;
    }
    if (settingId === SETTING_PROCESSING_AUTO_LOAD_OUTPUT) {
      return this.processingAutoLoadOutput;
    }
    if (settingId === SETTING_PROCESSING_KEEP_HISTORY) {
      return this.processingKeepHistory;
    }
    return this.mouseScrollOptimization;
  }

  private setBooleanSetting(settingId: number, value: boolean): void {
    if (settingId === SETTING_STARTUP_ANIMATION) {
      this.startupAnimationEnabled = value;
    } else if (settingId === SETTING_OPEN_SIDE_PANES) {
      this.openSidePanesOnStartup = value;
    } else if (settingId === SETTING_IMMERSIVE_MATERIAL) {
      this.materialEnabled = value;
    } else if (settingId === SETTING_PROGRESSIVE_LOADING) {
      this.progressiveLoading = value;
    } else if (settingId === SETTING_POINTER_SMOOTHING) {
      this.pointerSmoothing = value;
    } else if (settingId === SETTING_REDUCED_MOTION) {
      this.reducedMotion = value;
    } else if (settingId === SETTING_FLOATING_TAB_MATERIAL) {
      this.floatingTabMaterial = value;
    } else if (settingId === SETTING_PROCESSING_OVERWRITE_OUTPUT) {
      this.processingOverwriteOutput = value;
    } else if (settingId === SETTING_PROCESSING_AUTO_LOAD_OUTPUT) {
      this.processingAutoLoadOutput = value;
    } else if (settingId === SETTING_PROCESSING_KEEP_HISTORY) {
      this.processingKeepHistory = value;
    } else {
      this.mouseScrollOptimization = value;
    }
    this.refreshUi();
    this.persist();
  }

  private resetSettings(): void {
    this.materialQuality = MATERIAL_QUALITY_BALANCED;
    this.interfaceDensity = INTERFACE_DENSITY_AUTO;
    this.mapRenderQuality = MAP_RENDER_QUALITY_BALANCED;
    this.framePacing = FRAME_PACING_BALANCED;
    this.cacheStrategy = CACHE_STRATEGY_BALANCED;
    this.startupAnimationEnabled = DEFAULT_STARTUP_ANIMATION_ENABLED;
    this.openSidePanesOnStartup = DEFAULT_OPEN_SIDE_PANES;
    this.materialEnabled = DEFAULT_MATERIAL_ENABLED;
    this.progressiveLoading = DEFAULT_PROGRESSIVE_LOADING;
    this.pointerSmoothing = DEFAULT_POINTER_SMOOTHING;
    this.reducedMotion = DEFAULT_REDUCED_MOTION;
    this.floatingTabMaterial = DEFAULT_FLOATING_TAB_MATERIAL;
    this.mouseScrollOptimization = DEFAULT_MOUSE_SCROLL_OPTIMIZATION;
    this.processingOutputFolder = DEFAULT_PROCESSING_OUTPUT_FOLDER;
    this.processingOutputFolderDraft = DEFAULT_PROCESSING_OUTPUT_FOLDER;
    this.processingOverwriteOutput = DEFAULT_PROCESSING_OVERWRITE_OUTPUT;
    this.processingAutoLoadOutput = DEFAULT_PROCESSING_AUTO_LOAD_OUTPUT;
    this.processingKeepHistory = DEFAULT_PROCESSING_KEEP_HISTORY;
    this.processingHistoryLimit = DEFAULT_PROCESSING_HISTORY_LIMIT;
    this.applyThemeMode(THEME_MODE_SYSTEM);
    this.persist();
  }

  private itemRadius(): number {
    if (this.materialQuality === MATERIAL_QUALITY_EFFICIENT) {
      return 4;
    }
    if (this.materialQuality === MATERIAL_QUALITY_REFINED) {
      return 10;
    }
    return 7;
  }

  @Builder
  categoryItem(label: ResourceStr, icon: Resource, category: number) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 10 }) {
        SymbolGlyph(icon)
          .fontSize(18)
          .fontColor([this.selectedCategory === category ? $r('app.color.gn_blue_800') :
            $r('sys.color.icon_secondary')])
        Text(label)
          .fontSize(13)
          .fontWeight(this.selectedCategory === category ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.selectedCategory === category ? $r('app.color.gn_blue_800') :
            $r('app.color.gn_text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Start)
      }
      .width('100%')
    }
    .width('100%')
    .height(44)
    .padding({ left: 14, right: 12 })
    .backgroundColor(this.selectedCategory === category ? $r('app.color.gn_arc_active') : Color.Transparent)
    .borderRadius(this.itemRadius())
    .onClick(() => {
      this.selectedCategory = category;
    })
  }

  @Builder
  sectionHeader(title: ResourceStr, description: ResourceStr, icon: Resource) {
    Row({ space: 12 }) {
      SymbolGlyph(icon)
        .fontSize(22)
        .fontColor([$r('app.color.gn_blue_800')])
      Column({ space: 3 }) {
        Text(title)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary'))
        Text(description)
          .fontSize(12)
          .fontColor($r('app.color.gn_text_muted'))
      }
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ bottom: 8 })
  }

  @Builder
  profileOption(label: ResourceStr, group: number, value: number) {
    Button(label, { type: ButtonType.Normal, stateEffect: true })
      .layoutWeight(1)
      .height(38)
      .fontSize(12)
      .fontWeight(this.profileValue(group) === value ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.profileValue(group) === value ? Color.White : $r('app.color.gn_text_primary'))
      .backgroundColor(this.profileValue(group) === value ? $r('app.color.gn_blue_800') :
        $r('app.color.gn_paper'))
      .borderRadius(this.itemRadius())
      .border({
        width: 1,
        color: this.profileValue(group) === value ? $r('app.color.gn_blue_800') : $r('app.color.gn_line')
      })
      .onClick(() => {
        this.setProfile(group, value);
      })
  }

  @Builder
  profileRow(title: ResourceStr, description: ResourceStr, group: number,
    firstLabel: ResourceStr, firstValue: number, secondLabel: ResourceStr, secondValue: number,
    thirdLabel: ResourceStr, thirdValue: number) {
    Column({ space: 8 }) {
      Row() {
        Column({ space: 2 }) {
          Text(title)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.gn_text_primary'))
          Text(description)
            .fontSize(10)
            .fontColor($r('app.color.gn_text_muted'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      Row({ space: 8 }) {
        this.profileOption(firstLabel, group, firstValue)
        this.profileOption(secondLabel, group, secondValue)
        this.profileOption(thirdLabel, group, thirdValue)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ top: 10, bottom: 12 })
    .border({ width: { bottom: 1 }, color: $r('app.color.gn_line') })
  }

  @Builder
  switchRow(title: ResourceStr, description: ResourceStr, settingId: number) {
    Row({ space: 16 }) {
      Column({ space: 3 }) {
        Text(title)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary'))
        Text(description)
          .fontSize(10)
          .fontColor($r('app.color.gn_text_muted'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Toggle({ type: ToggleType.Switch, isOn: this.booleanSettingValue(settingId) })
        .selectedColor($r('app.color.gn_blue_800'))
        .onChange((value: boolean) => {
          this.setBooleanSetting(settingId, value);
        })
    }
    .width('100%')

    .padding({ top: 8, bottom: 8 })
    .border({ width: { bottom: 1 }, color: $r('app.color.gn_line') })
  }

  private sanitizedProcessingFolder(value: string): string {
    let source: string = value.trim();
    let result: string = '';
    for (let i: number = 0; i < source.length; i++) {
      let ch: string = source.charAt(i);
      if (ch === '/' || ch === '\\' || ch === ':' || ch === '*' || ch === '?' || ch === '"' ||
        ch === '<' || ch === '>' || ch === '|' || ch === '\r' || ch === '\n' || ch === '\t') {
        result += '_';
      } else {
        result += ch;
      }
    }
    if (result.length === 0 || result === '.' || result === '..') {
      return DEFAULT_PROCESSING_OUTPUT_FOLDER;
    }
    return result;
  }

  private applyProcessingOutputFolder(): void {
    this.processingOutputFolderDraft = this.sanitizedProcessingFolder(this.processingOutputFolderDraft);
    this.processingOutputFolder = this.processingOutputFolderDraft;
    this.refreshUi();
    this.persist();
  }

  private setProcessingHistoryLimit(value: number): void {
    this.processingHistoryLimit = value;
    this.refreshUi();
    this.persist();
  }

  @Builder
  processingHistoryLimitOption(label: ResourceStr, value: number) {
    Button(label, { type: ButtonType.Normal, stateEffect: true })
      .layoutWeight(1)
      .height(36)
      .fontSize(12)
      .fontColor(this.processingHistoryLimit === value ? Color.White : $r('app.color.gn_text_primary'))
      .backgroundColor(this.processingHistoryLimit === value ? $r('app.color.gn_blue_800') :
        $r('app.color.gn_paper'))
      .borderRadius(this.itemRadius())
      .border({
        width: 1,
        color: this.processingHistoryLimit === value ? $r('app.color.gn_blue_800') : $r('app.color.gn_line')
      })
      .onClick(() => {
        this.setProcessingHistoryLimit(value);
      })
  }

  @Builder
  processingOutputWorkspaceRow() {
    Column({ space: 8 }) {
      Text($r('app.string.gn_settings_processing_output_folder'))
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.gn_text_primary'))
      Text($r('app.string.gn_settings_processing_output_folder_desc'))
        .fontSize(10)
        .fontColor($r('app.color.gn_text_muted'))
      Row({ space: 8 }) {
        TextInput({ text: this.processingOutputFolderDraft,
          placeholder: $r('app.string.gn_settings_processing_output_folder_placeholder') })
          .layoutWeight(1)
          .height(38)
          .fontSize(12)
          .backgroundColor($r('app.color.gn_pane'))
          .onChange((value: string) => {
            this.processingOutputFolderDraft = value;
          })
        Button($r('app.string.gn_settings_processing_apply'), { type: ButtonType.Normal, stateEffect: true })
          .height(38)
          .fontSize(12)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.gn_blue_800'))
          .borderRadius(this.itemRadius())
          .onClick(() => {
            this.applyProcessingOutputFolder();
          })
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 10, bottom: 12 })
    .border({ width: { bottom: 1 }, color: $r('app.color.gn_line') })
  }

  @Builder
  appearanceContent() {
    Column() {
      this.sectionHeader($r('app.string.gn_settings_appearance'),
        $r('app.string.gn_settings_appearance_desc'), $r('sys.symbol.paintbrush'))
      this.profileRow($r('app.string.gn_settings_theme_mode'), $r('app.string.gn_settings_theme_mode_desc'),
        PROFILE_THEME,
        $r('app.string.gn_settings_theme_system'), THEME_MODE_SYSTEM,
        $r('app.string.gn_settings_theme_light'), THEME_MODE_LIGHT,
        $r('app.string.gn_settings_theme_dark'), THEME_MODE_DARK)
      this.profileRow($r('app.string.gn_settings_material_quality'),
        $r('app.string.gn_settings_material_quality_desc'), PROFILE_MATERIAL,
        $r('app.string.gn_settings_material_efficient'), MATERIAL_QUALITY_EFFICIENT,
        $r('app.string.gn_settings_material_balanced'), MATERIAL_QUALITY_BALANCED,
        $r('app.string.gn_settings_material_refined'), MATERIAL_QUALITY_REFINED)
      this.switchRow($r('app.string.gn_settings_immersive_material'),
        $r('app.string.gn_settings_immersive_material_desc'), SETTING_IMMERSIVE_MATERIAL)
    }
    .width('100%')
  }

  @Builder
  workspaceContent() {
    Column() {
      this.sectionHeader($r('app.string.gn_settings_workspace'),
        $r('app.string.gn_settings_workspace_desc'), $r('sys.symbol.square_grid_2x2'))
      this.profileRow($r('app.string.gn_settings_interface_density'),
        $r('app.string.gn_settings_interface_density_desc'), PROFILE_DENSITY,
        $r('app.string.gn_settings_density_compact'), INTERFACE_DENSITY_COMPACT,
        $r('app.string.gn_settings_density_auto'), INTERFACE_DENSITY_AUTO,
        $r('app.string.gn_settings_density_comfortable'), INTERFACE_DENSITY_COMFORTABLE)
      this.switchRow($r('app.string.gn_settings_startup_animation'),
        $r('app.string.gn_settings_startup_animation_desc'), SETTING_STARTUP_ANIMATION)
      this.switchRow($r('app.string.gn_settings_open_side_panes'),
        $r('app.string.gn_settings_open_side_panes_desc'), SETTING_OPEN_SIDE_PANES)
    }
    .width('100%')
  }

  @Builder
  mapPerformanceContent() {
    Column() {
      this.sectionHeader($r('app.string.gn_settings_map_performance'),
        $r('app.string.gn_settings_map_performance_desc'), $r('sys.symbol.map'))
      this.profileRow($r('app.string.gn_settings_render_quality'),
        $r('app.string.gn_settings_render_quality_desc'), PROFILE_RENDER,
        $r('app.string.gn_settings_profile_low'), MAP_RENDER_QUALITY_EFFICIENT,
        $r('app.string.gn_settings_profile_balanced'), MAP_RENDER_QUALITY_BALANCED,
        $r('app.string.gn_settings_profile_high'), MAP_RENDER_QUALITY_REFINED)
      this.profileRow($r('app.string.gn_settings_frame_pacing'),
        $r('app.string.gn_settings_frame_pacing_desc'), PROFILE_FRAME,
        $r('app.string.gn_settings_frame_30'), FRAME_PACING_POWER_SAVE,
        $r('app.string.gn_settings_frame_60'), FRAME_PACING_BALANCED,
        $r('app.string.gn_settings_frame_90'), FRAME_PACING_HIGH)
      this.profileRow($r('app.string.gn_settings_cache_strategy'),
        $r('app.string.gn_settings_cache_strategy_desc'), PROFILE_CACHE,
        $r('app.string.gn_settings_cache_conservative'), CACHE_STRATEGY_CONSERVATIVE,
        $r('app.string.gn_settings_profile_balanced'), CACHE_STRATEGY_BALANCED,
        $r('app.string.gn_settings_cache_aggressive'), CACHE_STRATEGY_AGGRESSIVE)
      this.switchRow($r('app.string.gn_settings_progressive_loading'),
        $r('app.string.gn_settings_progressive_loading_desc'), SETTING_PROGRESSIVE_LOADING)
    }
    .width('100%')
  }

  @Builder
  inputContent() {
    Column() {
      this.sectionHeader($r('app.string.gn_settings_input'),
        $r('app.string.gn_settings_input_desc'), $r('sys.symbol.hand_tap'))
      this.switchRow($r('app.string.gn_settings_pointer_smoothing'),
        $r('app.string.gn_settings_pointer_smoothing_desc'), SETTING_POINTER_SMOOTHING)
      this.switchRow($r('app.string.gn_settings_mouse_scroll'),
        $r('app.string.gn_settings_mouse_scroll_desc'), SETTING_MOUSE_SCROLL_OPTIMIZATION)
    }
    .width('100%')
  }

  @Builder
  accessibilityContent() {
    Column() {
      this.sectionHeader($r('app.string.gn_settings_accessibility'),
        $r('app.string.gn_settings_accessibility_desc'), $r('sys.symbol.person'))
      this.switchRow($r('app.string.gn_settings_reduced_motion'),
        $r('app.string.gn_settings_reduced_motion_desc'), SETTING_REDUCED_MOTION)
    }
    .width('100%')
  }

  @Builder
  processingContent() {
    Column() {
      this.sectionHeader($r('app.string.gn_settings_processing'),
        $r('app.string.gn_settings_processing_desc'), $r('sys.symbol.wrench_arrow_counterclockwise'))
      this.processingOutputWorkspaceRow()
      this.switchRow($r('app.string.gn_settings_processing_overwrite'),
        $r('app.string.gn_settings_processing_overwrite_desc'), SETTING_PROCESSING_OVERWRITE_OUTPUT)
      this.switchRow($r('app.string.gn_settings_processing_auto_load'),
        $r('app.string.gn_settings_processing_auto_load_desc'), SETTING_PROCESSING_AUTO_LOAD_OUTPUT)
      this.switchRow($r('app.string.gn_settings_processing_keep_history'),
        $r('app.string.gn_settings_processing_keep_history_desc'), SETTING_PROCESSING_KEEP_HISTORY)
      Column({ space: 8 }) {
        Text($r('app.string.gn_settings_processing_history_limit'))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary'))
        Text($r('app.string.gn_settings_processing_history_limit_desc'))
          .fontSize(10)
          .fontColor($r('app.color.gn_text_muted'))
        Row({ space: 8 }) {
          this.processingHistoryLimitOption($r('app.string.gn_settings_processing_history_20'), 20)
          this.processingHistoryLimitOption($r('app.string.gn_settings_processing_history_50'), 50)
          this.processingHistoryLimitOption($r('app.string.gn_settings_processing_history_100'), 100)
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ top: 10, bottom: 12 })
    }
    .width('100%')
  }

  @Builder
  api26Content() {
    Column() {
      this.sectionHeader($r('app.string.gn_settings_api26_lab'),
        $r('app.string.gn_settings_api26_lab_desc'), $r('sys.symbol.wrench_arrow_counterclockwise'))
      Row({ space: 8 }) {
        Text($r('app.string.gn_settings_api26_badge'))
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor($r('app.color.gn_blue_800'))
          .borderRadius(12)
        Text(MaterialStyle.supportsNativeMaterial() ?
          $r('app.string.gn_settings_api26_available') : $r('app.string.gn_settings_api26_fallback'))
          .fontSize(11)
          .fontColor($r('app.color.gn_text_muted'))
      }
      .width('100%')
      .padding({ top: 8, bottom: 14 })
      this.switchRow($r('app.string.gn_settings_floating_tab_material'),
        $r('app.string.gn_settings_floating_tab_material_desc'), SETTING_FLOATING_TAB_MATERIAL)
      this.switchRow($r('app.string.gn_settings_progressive_loading'),
        $r('app.string.gn_settings_progressive_loading_desc'), SETTING_PROGRESSIVE_LOADING)
      this.switchRow($r('app.string.gn_settings_mouse_scroll'),
        $r('app.string.gn_settings_mouse_scroll_desc'), SETTING_MOUSE_SCROLL_OPTIMIZATION)
      Text($r('app.string.gn_settings_api26_note'))
        .fontSize(10)
        .fontColor($r('app.color.gn_text_muted'))
        .width('100%')
        .padding({ top: 14 })
    }
    .width('100%')
  }

  @Builder
  selectedContent() {
    Text(this.uiRevision.toString())
      .width(0)
      .height(0)
      .fontSize(0)
      .opacity(0)
    if (this.selectedCategory === CATEGORY_APPEARANCE) {
      this.appearanceContent()
    } else if (this.selectedCategory === CATEGORY_WORKSPACE) {
      this.workspaceContent()
    } else if (this.selectedCategory === CATEGORY_MAP_PERFORMANCE) {
      this.mapPerformanceContent()
    } else if (this.selectedCategory === CATEGORY_INPUT) {
      this.inputContent()
    } else if (this.selectedCategory === CATEGORY_ACCESSIBILITY) {
      this.accessibilityContent()
    } else if (this.selectedCategory === CATEGORY_PROCESSING) {
      this.processingContent()
    } else {
      this.api26Content()
    }
  }

  build() {
    Row()
      .width(0)
      .height(0)
      .bindSheet($$this.isShow, this.sheetContent(), {
        width: 900,
        height: 690,
        detents: [690],
        preferType: SheetType.CENTER,
        dragBar: false,
        backgroundColor: Color.Transparent,
        blurStyle: BlurStyle.Regular,
        showClose: false,
        onDisappear: (): void => {
          this.isShow = false;
        }
      })
  }

  @Builder
  sheetContent() {
    Column() {
      HdsNavigation() {
        Row() {
          Scroll() {
            Column({ space: 4 }) {
              Blank().height(80).width('100%')
              Text($r('app.string.gn_settings_title'))
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.gn_text_muted'))
                .width('100%')
                .padding({ left: 14, bottom: 8 })
              this.categoryItem($r('app.string.gn_settings_appearance'), $r('sys.symbol.paintbrush'),
                CATEGORY_APPEARANCE)
              this.categoryItem($r('app.string.gn_settings_workspace'), $r('sys.symbol.square_grid_2x2'),
                CATEGORY_WORKSPACE)
              this.categoryItem($r('app.string.gn_settings_map_performance'), $r('sys.symbol.map'),
                CATEGORY_MAP_PERFORMANCE)
              this.categoryItem($r('app.string.gn_settings_input'), $r('sys.symbol.hand_tap'), CATEGORY_INPUT)
              this.categoryItem($r('app.string.gn_settings_accessibility'), $r('sys.symbol.person'),
                CATEGORY_ACCESSIBILITY)
              this.categoryItem($r('app.string.gn_settings_processing'),
                $r('sys.symbol.wrench_arrow_counterclockwise'), CATEGORY_PROCESSING)
              this.categoryItem($r('app.string.gn_settings_api26_lab'),
                $r('sys.symbol.wrench_arrow_counterclockwise'), CATEGORY_API26)
              Blank()
              Button($r('app.string.gn_settings_reset'), { type: ButtonType.Normal, stateEffect: true })
                .width('100%')
                .height(36)
                .fontSize(12)
                .fontColor($r('app.color.gn_blue_800'))
                .backgroundColor(Color.Transparent)
                .onClick(() => {
                  this.resetSettings();
                })
            }
            .width('100%')
            .padding({ left: 14, right: 14, top: 18, bottom: 14 })
          }
          .width(210)
          .height('100%')
          .scrollBar(BarState.Auto)
          .backgroundColor(Color.Transparent)
          .border({ width: { right: 1 }, color: $r('app.color.gn_line') })

          Scroll(this.contentScroller) {
            Column() {
              Blank().height(80).width('100%')
              this.selectedContent()
            }
            .width('100%')
            .padding(22)
            .backgroundColor(Color.Transparent)
            .borderRadius(8)
          }
          .layoutWeight(1)
          .height('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 16 })
          .backgroundColor(Color.Transparent)
          .scrollBar(BarState.Auto)
          .scrollBarWidth(6)
          .edgeEffect(EdgeEffect.Spring)
        }
        .width('100%')
        .height('100%')
      }
      .mode(NavigationMode.Stack)
      .titleMode(HdsNavigationTitleMode.MODAL)
      .titleBar({
        style: MaterialStyle.isHigh() && this.materialEnabled ? {
          scrollEffectOpts: { scrollEffectType: ScrollEffectType.GRADIENT_BLUR },
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.IMMERSIVE,
            materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
          }
        } : undefined,
        content: {
          title: {
            mainTitle: $r('app.string.gn_settings_title'),
            subTitle: $r('app.string.gn_settings_subtitle')
          },
          menu: {
            value: [{
              content: {
                label: 'modal_cancel',
                isEnabled: true,
                type: IconStyleMode.SMALL,
                action: () => {
                  this.isShow = false;
                }
              }
            }]
          }
        }
      })
      .bindToScrollable([this.contentScroller])
    }
    .width('100%')
    .height('100%')
  }
}
