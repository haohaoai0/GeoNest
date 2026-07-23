import { MaterialStyle } from '@geonest/common';
import { WorkbenchSearchCandidateKind } from '../constants/WorkbenchConstants';
import { GlobalSearchCandidate } from '../model/WorkbenchModels';

@Component
export struct WorkbenchCommandSearchPopup {
  @Prop searchText: string = '';
  @Prop candidates: GlobalSearchCandidate[] = [];
  @Prop itemRadius: number = 6;
  @Prop paneRadius: number = 8;
  @Prop surfaceColor: ResourceColor = Color.Transparent;
  resolveGeometryIcon: (geometryType: number) => Resource = (geometryType: number): Resource => {
    return $r('sys.symbol.layer');
  };
  onSelect: (item: GlobalSearchCandidate) => void = (item: GlobalSearchCandidate): void => {};

  @Builder
  symbol(icon: Resource, color: ResourceColor, sizeValue: number) {
    SymbolGlyph(icon)
      .fontSize(sizeValue)
      .fontColor([color])
  }

  @Builder
  noResultItem() {
    Row({ space: 8 }) {
      this.symbol($r('sys.symbol.magnifyingglass'), $r('sys.color.icon_secondary'), 16)
      Column() {
        Text('未找到匹配项')
          .fontSize(13)
          .fontColor($r('app.color.gn_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.searchText)
          .fontSize(11)
          .fontColor($r('app.color.gn_text_muted'))
          .margin({ top: 2 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .height(54)
    .padding({ left: 12, right: 12 })
    .width('100%')
  }

  @Builder
  suggestionItem(item: GlobalSearchCandidate) {
    Row({ space: 10 }) {
      if (item.kind === WorkbenchSearchCandidateKind.LAYER) {
        this.symbol(this.resolveGeometryIcon(item.geometryType), $r('app.color.gn_green_700'), 18)
      } else {
        this.symbol($r('sys.symbol.wrench_arrow_counterclockwise'), $r('app.color.gn_blue_800'), 18)
      }
      Column() {
        Row({ space: 6 }) {
          Text(item.title)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.gn_text_primary'))
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(item.category)
            .fontSize(10)
            .fontColor(item.kind === WorkbenchSearchCandidateKind.LAYER ? $r('app.color.gn_green_700') :
              $r('app.color.gn_blue_800'))
            .backgroundColor(item.kind === WorkbenchSearchCandidateKind.LAYER ? $r('app.color.gn_pane_alt') :
              $r('app.color.gn_blue_100'))
            .borderRadius(4)
            .padding({ left: 5, right: 5, top: 1, bottom: 1 })
        }
        .width('100%')
        Text(item.subtitle)
          .fontSize(11)
          .fontColor($r('app.color.gn_text_muted'))
          .margin({ top: 3 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      this.symbol($r('sys.symbol.chevron_right'), $r('sys.color.icon_secondary'), 12)
    }
    .height(54)
    .padding({ left: 12, right: 10 })
    .margin({ left: 6, right: 6, top: 2, bottom: 2 })
    .borderRadius(this.itemRadius)
    .backgroundColor($r('app.color.gn_paper'))
    .onClick(() => {
      this.onSelect(item);
    })
  }

  build() {
    Column() {
      if (this.candidates.length === 0) {
        this.noResultItem()
      } else {
        ForEach(this.candidates, (item: GlobalSearchCandidate) => {
          this.suggestionItem(item)
        }, (item: GlobalSearchCandidate) => item.key)
      }
    }
    .width(420)
    .padding({ top: 6, bottom: 6 })
    .backgroundBlurStyle(MaterialStyle.panelBlurStyle())
    .backgroundColor(this.surfaceColor)
    .borderRadius(this.paneRadius)
    .border({ width: 1, color: $r('app.color.gn_line_strong') })
    .shadow({ radius: 14, color: '#26000000', offsetX: 0, offsetY: 8 })
    .clip(true)
    .position({ x: 376, y: 82 })
    .zIndex(20)
  }
}
