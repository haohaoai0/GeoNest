import { HdsNavigation, HdsNavigationTitleMode, IconStyleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { hdsMaterial } from '@hms.hds.hdsMaterial';
import { MaterialStyle } from '@geonest/common';
import {
  ACTION_EXPORT,
  ACTION_NEW_PROJECT,
  ACTION_OPEN_PROJECT,
  ACTION_PROJECT_INFO,
  ACTION_SAVE_PROJECT,
  ACTION_SETTINGS,
  BACKSTAGE_ABOUT,
  BACKSTAGE_HELP,
  BACKSTAGE_INFO,
  BACKSTAGE_SETTINGS
} from '../constants/WorkbenchConstants';

@Component
export struct WorkbenchBackstage {
  @Prop section: number = BACKSTAGE_INFO;
  @Prop dialogTitle: ResourceStr = '';
  @Prop projectName: ResourceStr = '';
  @Prop projectFileText: ResourceStr = '';
  @Prop projectOwner: ResourceStr = '';
  @Prop projectMapName: ResourceStr = '';
  @Prop projectWorkspaceName: ResourceStr = '';
  @Prop layerStatsText: ResourceStr = '';
  @Prop mapReferenceStatus: ResourceStr = '';
  @Prop mapStatusText: ResourceStr = '';
  @Prop nativeBridgeVersion: string = '';
  @Prop openSourceNotices: string = '';
  @Prop noticesExpanded: boolean = false;
  @Prop paneRadius: number = 8;
  @Prop itemRadius: number = 6;
  onAction: (actionId: number) => void = (actionId: number): void => {};
  onDismiss: () => void = (): void => {};
  onNoticesExpandedChanged: (expanded: boolean) => void = (expanded: boolean): void => {};

  @Builder
  symbol(icon: Resource, color: ResourceColor, sizeValue: number) {
    SymbolGlyph(icon)
      .fontSize(sizeValue)
      .fontColor([color])
  }

  @Builder
  menuCommand(label: ResourceStr, icon: Resource, actionId: number) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 10 }) {
        this.symbol(icon, $r('sys.color.icon_secondary'), 18)
        Text(label)
          .fontSize(14)
          .fontColor($r('app.color.gn_text_primary'))
          .layoutWeight(1)
      }
      .padding({ left: 18, right: 14 })
      .width('100%')
      .height(48)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(48)
    .padding(0)
    .backgroundColor(Color.Transparent)
    .borderRadius(0)
    .onClick(() => {
      this.onAction(actionId);
    })
  }

  @Builder
  infoRow(label: ResourceStr, value: ResourceStr) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor($r('app.color.gn_text_muted'))
        .width(116)
      Text(value)
        .fontSize(13)
        .fontColor($r('app.color.gn_text_primary'))
        .layoutWeight(1)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ top: 4, bottom: 4 })
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  actionButton(label: ResourceStr, icon: Resource, actionId: number) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 8 }) {
        this.symbol(icon, $r('app.color.gn_blue_800'), 17)
        Text(label)
          .fontSize(13)
          .fontColor($r('app.color.gn_blue_800'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .justifyContent(FlexAlign.Center)
      .width('100%')
    }
    .layoutWeight(1)
    .height(36)
    .padding({ left: 12, right: 12 })
    .borderRadius(this.itemRadius)
    .backgroundColor($r('app.color.gn_blue_100'))
    .onClick(() => {
      this.onAction(actionId);
    })
  }

  @Builder
  infoPanel() {
    Column({ space: 16 }) {
      Text($r('app.string.gn_backstage_project_summary'))
        .fontSize(28)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.gn_blue_800'))
        .width('100%')
      Column({ space: 8 }) {
        this.infoRow($r('app.string.gn_project_name_label'), this.projectName)
        this.infoRow($r('app.string.gn_project_file_label'), this.projectFileText)
        this.infoRow($r('app.string.gn_project_owner_label'), this.projectOwner)
        this.infoRow($r('app.string.gn_project_map_name_label'), this.projectMapName)
        this.infoRow($r('app.string.gn_project_workspace_label'), this.projectWorkspaceName)
        this.infoRow($r('app.string.gn_project_layer_count_label'), this.layerStatsText)
        this.infoRow($r('app.string.gn_backstage_reference_status'), this.mapReferenceStatus)
        this.infoRow($r('app.string.gn_backstage_map_status'), this.mapStatusText)
      }
      .padding(18)
      .borderRadius(this.paneRadius)
      .backgroundColor($r('app.color.gn_paper'))
      .border({ width: 1, color: $r('app.color.gn_line') })
      Row({ space: 10 }) {
        this.actionButton($r('app.string.gn_project_info'), $r('sys.symbol.info_circle'), ACTION_PROJECT_INFO)
        this.actionButton($r('app.string.gn_workbench_save'), $r('sys.symbol.archivebox_fill'), ACTION_SAVE_PROJECT)
        this.actionButton($r('app.string.gn_cmd_export'), $r('sys.symbol.download'), ACTION_EXPORT)
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  aboutPanel() {
    Column({ space: 16 }) {
      Text($r('app.string.gn_backstage_product_title'))
        .fontSize(30)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.gn_blue_800'))
        .width('100%')
      Text($r('app.string.gn_backstage_product_desc'))
        .fontSize(14)
        .fontColor($r('app.color.gn_text_primary'))
        .width('100%')
      Column({ space: 8 }) {
        Text($r('app.string.gn_open_source_license_title'))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary'))
          .width('100%')
        Text($r('app.string.gn_open_source_copyright')).fontSize(13)
          .fontColor($r('app.color.gn_text_primary')).width('100%')
        Text($r('app.string.gn_open_source_rights')).fontSize(13)
          .fontColor($r('app.color.gn_text_muted')).width('100%')
        Text($r('app.string.gn_open_source_no_warranty')).fontSize(13)
          .fontColor($r('app.color.gn_text_muted')).width('100%')
        Text($r('app.string.gn_open_source_source_entry')).fontSize(13)
          .fontColor($r('app.color.gn_blue_800')).width('100%')
        this.infoRow('GeoNest', 'GPL-2.0-or-later')
        this.infoRow('QGIS Core', 'GPL-2.0-or-later')
        this.infoRow('Qt', 'LGPL-3.0-only / GPL')
        this.infoRow('GDAL/OGR', 'MIT License')
        this.infoRow('GEOS', 'LGPL-2.1-or-later')
        this.infoRow('PROJ', 'MIT License')
        this.infoRow('SQLite', 'Public Domain')
        this.infoRow('Expat', 'MIT License')
        this.infoRow('Protobuf', 'BSD-3-Clause')
        this.infoRow('Zstd', 'BSD-3-Clause')
        this.infoRow('Libzip', 'BSD-3-Clause')
        this.infoRow('QtKeychain', 'BSD-3-Clause')
        Button(this.noticesExpanded ? $r('app.string.gn_open_source_hide_licenses') :
          $r('app.string.gn_open_source_show_licenses'), { type: ButtonType.Normal, stateEffect: true })
          .height(36)
          .fontSize(13)
          .fontColor($r('app.color.gn_blue_800'))
          .backgroundColor($r('app.color.gn_blue_100'))
          .borderRadius(this.itemRadius)
          .onClick(() => {
            this.onNoticesExpandedChanged(!this.noticesExpanded);
          })
        if (this.noticesExpanded) {
          Text(this.openSourceNotices)
            .fontSize(11)
            .fontColor($r('app.color.gn_text_primary'))
            .width('100%')
            .padding(12)
            .backgroundColor($r('app.color.gn_pane'))
            .borderRadius(this.itemRadius)
            .border({ width: 1, color: $r('app.color.gn_line') })
        }
      }
      .padding(18)
      .borderRadius(this.paneRadius)
      .backgroundColor($r('app.color.gn_paper'))
      .border({ width: 1, color: $r('app.color.gn_line') })
      Column({ space: 8 }) {
        Text($r('app.string.gn_open_source_qgis_title')).fontSize(16).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary')).width('100%')
        Text($r('app.string.gn_open_source_qgis_desc')).fontSize(13)
          .fontColor($r('app.color.gn_text_muted')).width('100%')
      }
      .padding(18)
      .borderRadius(this.paneRadius)
      .backgroundColor($r('app.color.gn_paper'))
      .border({ width: 1, color: $r('app.color.gn_line') })
      Text('GeoNest 版本 ' + this.nativeBridgeVersion)
        .fontSize(12)
        .fontColor($r('app.color.gn_text_muted'))
        .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  helpPanel() {
    Column({ space: 14 }) {
      Text($r('app.string.gn_backstage_help')).fontSize(28).fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.gn_blue_800')).width('100%')
      Column({ space: 8 }) {
        Text('快速入门').fontSize(16).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary')).width('100%')
        this.infoRow('添加数据', '点击"添加数据"按钮，选择 Shapefile、GeoJSON、GeoPackage 或栅格文件')
        this.infoRow('切换底图', '在状态栏点击底图名称，可切换在线地图或本地矢量底图')
        this.infoRow('图层管理', '在左侧图层面板控制图层显示、顺序和样式')
        this.infoRow('地图浏览', '拖拽平移，双指缩放，点击要素查看属性')
      }
      .padding(18).borderRadius(this.paneRadius).backgroundColor($r('app.color.gn_paper'))
      .border({ width: 1, color: $r('app.color.gn_line') })
      Column({ space: 8 }) {
        Text('常用工具').fontSize(16).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary')).width('100%')
        this.infoRow('矢量编辑', '新增点/线/面、移动节点、删除节点、切割、合并')
        this.infoRow('属性编辑', '查看和编辑要素属性表，支持字段计算')
        this.infoRow('空间分析', '裁剪、缓冲区、修复几何、投影转换')
        this.infoRow('地图出图', '设置布局、比例尺、图例，导出为图片或打印')
      }
      .padding(18).borderRadius(this.paneRadius).backgroundColor($r('app.color.gn_paper'))
      .border({ width: 1, color: $r('app.color.gn_line') })
      Column({ space: 8 }) {
        Text('键盘快捷键').fontSize(16).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary')).width('100%')
        this.infoRow('Ctrl+N', '新建工程')
        this.infoRow('Ctrl+O', '打开工程')
        this.infoRow('Ctrl+S', '保存工程')
        this.infoRow('Ctrl+Z', '撤销编辑')
        this.infoRow('Ctrl+Y', '重做编辑')
        this.infoRow('Ctrl+M', '全图显示')
        this.infoRow('Ctrl+L', '切换图层可见性')
        this.infoRow('Ctrl+T', '窗口置顶/取消置顶')
        this.infoRow('Ctrl+1', '放大')
        this.infoRow('Ctrl+2', '缩小')
        this.infoRow('Ctrl+Shift+C', '复制地图上下文')
        this.infoRow('Ctrl+Shift+V', '从剪贴板粘贴')
        this.infoRow('Ctrl+Shift+M', '打开第二地图窗口')
        this.infoRow('Ctrl+Shift+L', '切换多地图联动')
        this.infoRow('Ctrl+Shift+F', '探索工具')
        this.infoRow('Ctrl+Shift+I', '导入数据')
        this.infoRow('Delete', '删除选中要素')
        this.infoRow('Esc', '取消当前操作')
        this.infoRow('F1', '帮助')
        this.infoRow('F11', '切换图层可见性')
      }
      .padding(18).borderRadius(this.paneRadius).backgroundColor($r('app.color.gn_paper'))
      .border({ width: 1, color: $r('app.color.gn_line') })
      Column({ space: 8 }) {
        Text('鼠标与触控板').fontSize(16).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary')).width('100%')
        this.infoRow('滚轮', '缩放地图')
        this.infoRow('中键拖拽', '平移地图')
        this.infoRow('左键单击', '选择要素')
        this.infoRow('右键菜单', '地图操作菜单')
        this.infoRow('双指捏合', '缩放地图（触控板）')
        this.infoRow('双指滑动', '平移地图（触控板）')
      }
      .padding(18).borderRadius(this.paneRadius).backgroundColor($r('app.color.gn_paper'))
      .border({ width: 1, color: $r('app.color.gn_line') })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  settingsPanel() {
    Column({ space: 16 }) {
      Text($r('app.string.gn_settings_title')).fontSize(28).fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.gn_blue_800')).width('100%')
      Column({ space: 8 }) {
        this.infoRow($r('app.string.gn_settings_appearance'), '外观主题、材质效果')
        this.infoRow($r('app.string.gn_settings_workspace'), '启动面板、自动保存')
        this.infoRow($r('app.string.gn_settings_map_performance'), '底图、渲染质量')
        this.infoRow($r('app.string.gn_settings_input'), '手势与交互')
        this.infoRow($r('app.string.gn_settings_accessibility'), '字体大小、对比度')
      }
      .padding(18).borderRadius(this.paneRadius).backgroundColor($r('app.color.gn_paper'))
      .border({ width: 1, color: $r('app.color.gn_line') })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  content() {
    if (this.section === BACKSTAGE_ABOUT) {
      this.aboutPanel()
    } else if (this.section === BACKSTAGE_HELP) {
      this.helpPanel()
    } else if (this.section === BACKSTAGE_SETTINGS) {
      this.settingsPanel()
    } else {
      this.infoPanel()
    }
  }

  @Builder
  fileActions() {
    Scroll() {
      Column() {
        Blank().height(80).width('100%')
        this.menuCommand($r('app.string.gn_workbench_new'), $r('sys.symbol.doc_text'), ACTION_NEW_PROJECT)
        this.menuCommand($r('app.string.gn_workbench_open'), $r('sys.symbol.folder'), ACTION_OPEN_PROJECT)
        this.menuCommand($r('app.string.gn_workbench_save'), $r('sys.symbol.archivebox_fill'), ACTION_SAVE_PROJECT)
        this.menuCommand('另存工程', $r('sys.symbol.archivebox_fill'), ACTION_SAVE_PROJECT)
        Column().width('82%').height(1).backgroundColor($r('app.color.gn_line_strong'))
          .margin({ top: 12, bottom: 12 })
        this.menuCommand($r('app.string.gn_settings_title'), $r('sys.symbol.gearshape'), ACTION_SETTINGS)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .width(210)
    .height('100%')
    .scrollBar(BarState.Auto)
    .backgroundColor($r('app.color.gn_pane_alt'))
    .border({ width: { right: 1 }, color: $r('app.color.gn_line_strong') })
  }

  build() {
    Column() {
      HdsNavigation() {
        if (this.section === BACKSTAGE_INFO) {
          Row() {
            this.fileActions()
            Scroll() {
              Column() {
                Blank().height(80).width('100%')
                this.infoPanel()
              }
              .width('100%')
              .padding({ left: 24, right: 24, top: 14, bottom: 22 })
            }
            .layoutWeight(1)
            .height('100%')
            .scrollBar(BarState.Auto)
          }
          .layoutWeight(1)
          .width('100%')
        } else {
          Scroll() {
            Column() {
              Blank().height(80).width('100%')
              this.content()
            }
            .width('100%')
            .padding({ left: 28, right: 28, top: 14, bottom: 24 })
          }
          .layoutWeight(1)
          .width('100%')
          .scrollBar(BarState.Auto)
        }
      }
      .mode(NavigationMode.Stack)
      .titleMode(HdsNavigationTitleMode.MODAL)
      .titleBar({
        style: MaterialStyle.isHigh() ? {
          scrollEffectOpts: { scrollEffectType: ScrollEffectType.GRADIENT_BLUR },
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.IMMERSIVE,
            materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
          }
        } : undefined,
        content: {
          title: { mainTitle: this.dialogTitle },
          menu: {
            value: [{
              content: {
                label: 'modal_cancel',
                isEnabled: true,
                type: IconStyleMode.SMALL,
                action: () => {
                  this.onDismiss();
                }
              }
            }]
          }
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}
