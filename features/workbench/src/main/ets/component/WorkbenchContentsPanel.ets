import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { WorkbenchContentsAction, WorkbenchContentsSection } from '../constants/WorkbenchConstants';
import { LayerDisplayItem } from '../model/WorkbenchModels';

@Component
export struct WorkbenchContentsPanel {
  @Prop section: number = WorkbenchContentsSection.DRAWING_ORDER;
  @Prop searchText: string = '';
  @Prop selectedLayerIndex: number = -1;
  @Prop layerCount: number = 0;
  @Prop sectionSummary: string = '';
  @Prop basemapLayerName: string = '';
  @Prop items: LayerDisplayItem[] = [];
  @Prop itemRadius: number = 6;
  @State private hoverLayerIndex: number = -1;
  resolveGeometryIcon: (geometryType: number) => Resource = (geometryType: number): Resource => {
    return $r('sys.symbol.layer');
  };
  onAction: (actionId: number) => void = (actionId: number): void => {};
  onSectionChanged: (section: number) => void = (section: number): void => {};
  onSearchTextChanged: (value: string) => void = (value: string): void => {};
  onToggleVisibility: (layerIndex: number) => void = (layerIndex: number): void => {};
  onSelectLayer: (layerIndex: number) => void = (layerIndex: number): void => {};
  onOpenLabeling: () => void = (): void => {};
  onCreateDragItemInfo: (event: DragEvent, layerIndex: number) => DragItemInfo =
    (event: DragEvent, layerIndex: number): DragItemInfo => {
      return { pixelMap: undefined, extraInfo: '' };
    };
  onLayerDrop: (event: DragEvent, extraParams: string, layerIndex: number) => void =
    (event: DragEvent, extraParams: string, layerIndex: number): void => {};

  @Builder
  symbol(icon: Resource, color: ResourceColor, sizeValue: number) {
    SymbolGlyph(icon).fontSize(sizeValue).fontColor([color])
  }

  @Builder
  toolButton(icon: Resource, actionId: number) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      this.symbol(icon, $r('sys.color.icon_secondary'), 17)
    }
    .width(24).height(24).padding(0).backgroundColor(Color.Transparent)
    .onClick(() => {
      this.onAction(actionId);
    })
  }

  @Builder
  layerToolbar() {
    Row({ space: 10 }) {
      this.toolButton($r('sys.symbol.plus_square_on_square'), WorkbenchContentsAction.ADD_DATA)
      this.toolButton($r('sys.symbol.eye'), WorkbenchContentsAction.LAYER_TOGGLE)
      this.toolButton($r('sys.symbol.funnel'), WorkbenchContentsAction.LAYER_FILTER)
      this.toolButton($r('sys.symbol.arrow_up'), WorkbenchContentsAction.LAYER_UP)
      this.toolButton($r('sys.symbol.arrow_down'), WorkbenchContentsAction.LAYER_DOWN)
      this.toolButton($r('sys.symbol.trash'), WorkbenchContentsAction.LAYER_DELETE)
      Blank()
    }
    .height(34).padding({ left: 10, right: 8 }).backgroundColor($r('app.color.gn_pane'))
  }

  @Builder
  searchBox() {
    Search({ placeholder: $r('app.string.gn_contents_search_placeholder') })
      .height(30)
      .margin({ left: 8, right: 8, top: 8, bottom: 6 })
      .backgroundColor($r('app.color.gn_paper'))
      .borderRadius(this.itemRadius)
      .onChange((value: string) => {
        this.onSearchTextChanged(value);
      })
  }

  @Builder
  tabButton(label: ResourceStr, icon: Resource, section: number) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Column({ space: 2 }) {
        this.symbol(icon, this.section === section ? $r('app.color.gn_blue_800') :
          $r('sys.color.icon_secondary'), 17)
        Text(label).fontSize(9)
          .fontColor(this.section === section ? $r('app.color.gn_blue_800') : $r('app.color.gn_text_muted'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%').height(38).justifyContent(FlexAlign.Center)
    }
    .layoutWeight(1).height(42).padding(0)
    .backgroundColor(this.section === section ? $r('app.color.gn_paper') : Color.Transparent)
    .borderRadius(this.itemRadius)
    .border({ width: this.section === section ? 1 : 0, color: $r('app.color.gn_line') })
    .onClick(() => {
      this.onSectionChanged(section);
    })
  }

  @Builder
  tabBar() {
    Row({ space: 4 }) {
      this.tabButton($r('app.string.gn_contents_drawing_order'), $r('sys.symbol.list_bullet_square'),
        WorkbenchContentsSection.DRAWING_ORDER)
      this.tabButton($r('app.string.gn_contents_source'), $r('sys.symbol.externaldrive'),
        WorkbenchContentsSection.SOURCE)
      this.tabButton($r('app.string.gn_contents_selection'), $r('sys.symbol.checkmark_square'),
        WorkbenchContentsSection.SELECTION)
      this.tabButton($r('app.string.gn_contents_labeling'), $r('sys.symbol.textformat'),
        WorkbenchContentsSection.LABELING)
      this.tabButton($r('app.string.gn_contents_editing'), $r('sys.symbol.square_and_pencil'),
        WorkbenchContentsSection.EDITING)
    }
    .height(48).padding({ left: 8, right: 8, bottom: 6 }).backgroundColor($r('app.color.gn_pane'))
  }

  @Builder
  sectionHeader(title: ResourceStr) {
    Column() {
      Text(title).fontSize(13).fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.gn_text_primary')).width('100%')
      Text(this.sectionSummary).fontSize(11).fontColor($r('app.color.gn_text_muted'))
        .margin({ top: 3 }).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
    }
    .padding({ left: 14, right: 12, top: 6, bottom: 7 }).width('100%')
    .backgroundColor($r('app.color.gn_pane_alt'))
    .border({ width: { top: 1, bottom: 1 }, color: $r('app.color.gn_line') })
  }

  @Builder
  metaChip(label: ResourceStr, color: ResourceColor) {
    Text(label).height(20).padding({ left: 7, right: 7 }).fontSize(10).fontColor(color)
      .backgroundColor($r('app.color.gn_pane_alt')).borderRadius(this.itemRadius)
      .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
  }

  @Builder
  emptyState() {
    Column({ space: 6 }) {
      this.symbol($r('sys.symbol.plus_square_on_square'), $r('sys.color.icon_secondary'), 24)
      Text($r('app.string.gn_contents_empty_title')).fontSize(12).fontColor($r('app.color.gn_text_primary'))
      Text($r('app.string.gn_contents_empty_desc')).fontSize(11).fontColor($r('app.color.gn_text_muted'))
        .textAlign(TextAlign.Center).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%').padding({ left: 18, right: 18, top: 24, bottom: 24 })
  }

  @Builder
  searchEmptyState() {
    Column({ space: 6 }) {
      this.symbol($r('sys.symbol.magnifyingglass'), $r('sys.color.icon_secondary'), 22)
      Text('未找到匹配内容').fontSize(12).fontColor($r('app.color.gn_text_primary'))
      Text(this.searchText).fontSize(11).fontColor($r('app.color.gn_text_muted'))
        .textAlign(TextAlign.Center).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%').padding({ left: 18, right: 18, top: 24, bottom: 24 })
  }

  @Builder
  visibilityButton(checked: boolean, layerIndex: number) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      SymbolGlyph(checked ? $r('sys.symbol.checkmark_square') : $r('sys.symbol.square'))
        .fontSize(15)
        .fontColor([checked ? $r('app.color.gn_blue_800') : $r('sys.color.icon_secondary')])
    }
    .width(24).height(24).padding(0).backgroundColor(Color.Transparent)
    .onClick(() => {
      this.onToggleVisibility(layerIndex);
    })
  }

  @Builder
  drawingLayerItem(label: ResourceStr, icon: Resource, iconColor: ResourceColor, level: number,
    checked: boolean, selected: boolean, layerIndex: number) {
    Row({ space: 6 }) {
      Blank().width(level * 14)
      this.symbol(level === 0 ? $r('sys.symbol.chevron_down') : $r('sys.symbol.chevron_right'),
        $r('sys.color.icon_secondary'), 11)
      this.visibilityButton(checked, layerIndex)
      this.symbol(icon, checked ? iconColor : $r('sys.color.icon_secondary'), 16)
      Text(label).fontSize(13)
        .fontColor(checked ? $r('app.color.gn_text_primary') : $r('app.color.gn_text_muted'))
        .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      if (!checked && layerIndex >= 0) {
        Text('隐藏').fontSize(11).fontColor($r('app.color.gn_text_muted'))
      }
    }
    .height(28).padding({ left: 8, right: 8 }).margin({ left: 6, right: 6, top: 1, bottom: 1 })
    .borderRadius(this.itemRadius)
    .onHover((isHover: boolean) => {
      if (!selected && layerIndex >= 0) {
        this.hoverLayerIndex = isHover ? layerIndex : -1;
      }
    })
    .backgroundColor(selected ? $r('app.color.gn_arc_selected') :
      (this.hoverLayerIndex === layerIndex ? $r('app.color.gn_paper') : Color.Transparent))
    .onClick(() => {
      this.onSelectLayer(layerIndex);
    })
    .draggable(layerIndex >= 0)
    .allowDrop([utd.UniformDataType.PLAIN_TEXT, utd.UniformDataType.FILE, utd.UniformDataType.FILE_URI,
      utd.UniformDataType.FOLDER])
    .onDragStart((event: DragEvent): DragItemInfo => {
      return this.onCreateDragItemInfo(event, layerIndex);
    })
    .onDrop((event: DragEvent, extraParams?: string) => {
      this.onLayerDrop(event, extraParams === undefined ? '' : extraParams, layerIndex);
    })
  }

  @Builder
  sourceLayerItem(item: LayerDisplayItem) {
    Column({ space: 5 }) {
      Row({ space: 6 }) {
        this.symbol(this.resolveGeometryIcon(item.geomType),
          item.visible ? item.symbolColor : $r('sys.color.icon_secondary'), 16)
        Text(item.name).fontSize(13).fontWeight(FontWeight.Medium)
          .fontColor(item.visible ? $r('app.color.gn_text_primary') : $r('app.color.gn_text_muted'))
          .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }.width('100%')
      Text(item.sourceDisplayText).fontSize(10).fontColor($r('app.color.gn_text_muted')).width('100%')
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      Row({ space: 5 }) {
        this.metaChip(item.geometryText, $r('app.color.gn_blue_800'))
        this.metaChip(item.featureCount.toString() + ' 要素', $r('app.color.gn_text_muted'))
        this.metaChip(item.fieldCount.toString() + ' 字段', $r('app.color.gn_text_muted'))
      }.width('100%')
      Text(item.referenceText).fontSize(10).fontColor($r('app.color.gn_text_muted')).width('100%')
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%').padding({ left: 10, right: 10, top: 8, bottom: 8 })
    .margin({ left: 8, right: 8, top: 4 }).borderRadius(this.itemRadius)
    .backgroundColor(this.selectedLayerIndex === item.index ? $r('app.color.gn_arc_selected') :
      $r('app.color.gn_paper'))
    .border({ width: 1, color: $r('app.color.gn_line') })
    .onClick(() => {
      this.onSelectLayer(item.index);
    })
  }

  @Builder
  selectionLayerItem(item: LayerDisplayItem) {
    Row({ space: 8 }) {
      this.visibilityButton(item.visible, item.index)
      this.symbol(this.resolveGeometryIcon(item.geomType),
        item.visible ? item.symbolColor : $r('sys.color.icon_secondary'), 16)
      Column() {
        Text(item.name).fontSize(13)
          .fontColor(item.visible ? $r('app.color.gn_text_primary') : $r('app.color.gn_text_muted'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(item.selectedFeatureCount.toString() + ' 已选 · ' + item.featureCount.toString() + ' 要素')
          .fontSize(10)
          .fontColor(item.selectedFeatureCount > 0 ? $r('app.color.gn_blue_800') :
            $r('app.color.gn_text_muted')).margin({ top: 2 })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      if (item.selectedFeatureCount > 0) {
        this.symbol($r('sys.symbol.checkmark_circle'), $r('app.color.gn_blue_800'), 15)
      }
    }
    .height(44).padding({ left: 8, right: 8 }).margin({ left: 8, right: 8, top: 3 })
    .borderRadius(this.itemRadius)
    .backgroundColor(item.selectedFeatureCount > 0 ? $r('app.color.gn_blue_100') : Color.Transparent)
    .onClick(() => {
      this.onSelectLayer(item.index);
    })
  }

  @Builder
  labelingLayerItem(item: LayerDisplayItem) {
    Row({ space: 8 }) {
      this.symbol($r('sys.symbol.textformat'),
        item.visible ? item.symbolColor : $r('sys.color.icon_secondary'), 16)
      Column() {
        Text(item.name).fontSize(13)
          .fontColor(item.visible ? $r('app.color.gn_text_primary') : $r('app.color.gn_text_muted'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(item.labelText).fontSize(10)
          .fontColor(item.labelText === '标注关闭' ? $r('app.color.gn_text_muted') :
            $r('app.color.gn_blue_800')).margin({ top: 2 }).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Text(item.rendererText).fontSize(10).fontColor($r('app.color.gn_text_muted'))
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width(74)
    }
    .height(46).padding({ left: 10, right: 10 }).margin({ left: 8, right: 8, top: 3 })
    .borderRadius(this.itemRadius)
    .backgroundColor(this.selectedLayerIndex === item.index ? $r('app.color.gn_arc_selected') : Color.Transparent)
    .onClick(() => {
      this.onSelectLayer(item.index);
      this.onOpenLabeling();
    })
  }

  @Builder
  editingLayerItem(item: LayerDisplayItem) {
    Row({ space: 8 }) {
      this.symbol(item.activeEdit ? $r('sys.symbol.square_and_pencil') :
        this.resolveGeometryIcon(item.geomType), item.activeEdit ? $r('app.color.gn_blue_800') :
        $r('sys.color.icon_secondary'), 16)
      Column() {
        Text(item.name).fontSize(13).fontColor($r('app.color.gn_text_primary'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(item.geometryText + '图层 · ' + item.featureCount.toString() + ' 要素')
          .fontSize(10).fontColor($r('app.color.gn_text_muted')).margin({ top: 2 })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      if (item.activeEdit) {
        this.metaChip($r('app.string.gn_contents_active_edit'), $r('app.color.gn_blue_800'))
      }
    }
    .height(46).padding({ left: 10, right: 10 }).margin({ left: 8, right: 8, top: 3 })
    .borderRadius(this.itemRadius)
    .backgroundColor(item.activeEdit ? $r('app.color.gn_blue_100') : Color.Transparent)
    .onClick(() => {
      this.onSelectLayer(item.index);
    })
  }

  @Builder
  drawingOrderContent() {
    Column() {
      this.sectionHeader($r('app.string.gn_contents_drawing_order'))
      if (this.searchText.trim().length === 0) {
        this.drawingLayerItem($r('app.string.gn_map_section'), $r('sys.symbol.map'),
          $r('app.color.gn_blue_800'), 0, false, this.selectedLayerIndex === -1, -1)
        this.drawingLayerItem(this.basemapLayerName, $r('sys.symbol.map'), $r('app.color.gn_green_700'), 1,
          true, this.selectedLayerIndex === -2, -2)
      }
      ForEach(this.items, (item: LayerDisplayItem) => {
        this.drawingLayerItem(item.name, this.resolveGeometryIcon(item.geomType), item.symbolColor, 1,
          item.visible, this.selectedLayerIndex === item.index, item.index)
      }, (item: LayerDisplayItem) => item.stateKey)
      this.resultState()
    }.width('100%')
  }

  @Builder
  resultState() {
    if (this.layerCount === 0) {
      this.emptyState()
    } else if (this.items.length === 0) {
      this.searchEmptyState()
    }
  }

  @Builder
  sourceContent() {
    Column() {
      this.sectionHeader($r('app.string.gn_contents_source'))
      this.resultState()
      ForEach(this.items, (item: LayerDisplayItem) => {
        this.sourceLayerItem(item)
      }, (item: LayerDisplayItem) => 'source:' + item.stateKey)
    }.width('100%')
  }

  @Builder
  selectionContent() {
    Column() {
      this.sectionHeader($r('app.string.gn_contents_selection'))
      this.resultState()
      ForEach(this.items, (item: LayerDisplayItem) => {
        this.selectionLayerItem(item)
      }, (item: LayerDisplayItem) => 'selection:' + item.stateKey)
    }.width('100%')
  }

  @Builder
  labelingContent() {
    Column() {
      this.sectionHeader($r('app.string.gn_contents_labeling'))
      this.resultState()
      ForEach(this.items, (item: LayerDisplayItem) => {
        this.labelingLayerItem(item)
      }, (item: LayerDisplayItem) => 'labeling:' + item.stateKey)
    }.width('100%')
  }

  @Builder
  editingContent() {
    Column() {
      this.sectionHeader($r('app.string.gn_contents_editing'))
      this.resultState()
      ForEach(this.items, (item: LayerDisplayItem) => {
        this.editingLayerItem(item)
      }, (item: LayerDisplayItem) => 'editing:' + item.stateKey)
    }.width('100%')
  }

  @Builder
  contentBody() {
    if (this.section === WorkbenchContentsSection.SOURCE) {
      this.sourceContent()
    } else if (this.section === WorkbenchContentsSection.SELECTION) {
      this.selectionContent()
    } else if (this.section === WorkbenchContentsSection.LABELING) {
      this.labelingContent()
    } else if (this.section === WorkbenchContentsSection.EDITING) {
      this.editingContent()
    } else {
      this.drawingOrderContent()
    }
  }

  build() {
    Column() {
      this.layerToolbar()
      this.searchBox()
      this.tabBar()
      Scroll() {
        Column() {
          this.contentBody()
          Blank()
        }.width('100%')
      }
      .layoutWeight(1).scrollBar(BarState.Auto)
    }
    .layoutWeight(1)
  }
}
