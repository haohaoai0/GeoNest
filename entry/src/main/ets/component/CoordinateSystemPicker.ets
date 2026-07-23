import { HdsNavigation, HdsNavigationTitleMode, IconStyleMode } from '@kit.UIDesignKit';
import { MaterialStyle } from '@geonest/common';

const CRS_CATEGORY_GEOGRAPHIC: number = 0;
const CRS_CATEGORY_CHINA_PROJECTED: number = 1;
const CRS_CATEGORY_UTM: number = 2;
const CRS_CATEGORY_WORLD_PROJECTED: number = 3;

class CrsCatalogItem {
  code: string = '';
  name: string = '';
  detail: string = '';
  category: number = CRS_CATEGORY_GEOGRAPHIC;
  isGeographic: boolean = true;

  constructor(code: string, name: string, detail: string, category: number, isGeographic: boolean) {
    this.code = code;
    this.name = name;
    this.detail = detail;
    this.category = category;
    this.isGeographic = isGeographic;
  }
}

@Component
export struct CoordinateSystemPicker {
  @Prop @Watch('onTrigger') trigger: boolean = false;
  @Prop currentDefinition: string = '';
  @State private isShow: boolean = false;
  @State private selectedCategory: number = CRS_CATEGORY_GEOGRAPHIC;
  @State private searchText: string = '';
  @StorageLink('gnMaterialEnabled') private materialEnabled: boolean = true;
  onSelected: (definition: string) => void = () => {};

  onTrigger(): void {
    this.searchText = '';
    this.isShow = true;
  }

  private catalogItems(): CrsCatalogItem[] {
    return [
      new CrsCatalogItem('EPSG:4326', 'WGS 84', '全球通用经纬度，单位：度',
        CRS_CATEGORY_GEOGRAPHIC, true),
      new CrsCatalogItem('EPSG:4490', 'CGCS2000', '中国 2000 国家大地坐标系，单位：度',
        CRS_CATEGORY_GEOGRAPHIC, true),
      new CrsCatalogItem('EPSG:4214', 'Beijing 1954', '北京 1954 地理坐标系，单位：度',
        CRS_CATEGORY_GEOGRAPHIC, true),
      new CrsCatalogItem('EPSG:4610', 'Xian 1980', '西安 1980 地理坐标系，单位：度',
        CRS_CATEGORY_GEOGRAPHIC, true),
      new CrsCatalogItem('EPSG:4546', 'CGCS2000 / 3-degree GK CM 111E',
        'CGCS2000 三度带高斯-克吕格，中央经线 111°E', CRS_CATEGORY_CHINA_PROJECTED, false),
      new CrsCatalogItem('EPSG:4547', 'CGCS2000 / 3-degree GK CM 114E',
        'CGCS2000 三度带高斯-克吕格，中央经线 114°E', CRS_CATEGORY_CHINA_PROJECTED, false),
      new CrsCatalogItem('EPSG:32649', 'WGS 84 / UTM zone 49N',
        '北半球 UTM 49 带，单位：米', CRS_CATEGORY_UTM, false),
      new CrsCatalogItem('EPSG:32650', 'WGS 84 / UTM zone 50N',
        '北半球 UTM 50 带，单位：米', CRS_CATEGORY_UTM, false),
      new CrsCatalogItem('EPSG:32651', 'WGS 84 / UTM zone 51N',
        '北半球 UTM 51 带，单位：米', CRS_CATEGORY_UTM, false),
      new CrsCatalogItem('EPSG:3857', 'WGS 84 / Pseudo-Mercator',
        'Web 地图常用伪墨卡托，单位：米', CRS_CATEGORY_WORLD_PROJECTED, false),
      new CrsCatalogItem('EPSG:3395', 'WGS 84 / World Mercator',
        '世界墨卡托投影，单位：米', CRS_CATEGORY_WORLD_PROJECTED, false),
      new CrsCatalogItem('EPSG:3413', 'WGS 84 / NSIDC Sea Ice Polar Stereographic North',
        '北极极地立体投影，单位：米', CRS_CATEGORY_WORLD_PROJECTED, false),
      new CrsCatalogItem('EPSG:3031', 'WGS 84 / Antarctic Polar Stereographic',
        '南极极地立体投影，单位：米', CRS_CATEGORY_WORLD_PROJECTED, false)
    ];
  }

  private categoryName(category: number): string {
    if (category === CRS_CATEGORY_CHINA_PROJECTED) {
      return '中国投影';
    }
    if (category === CRS_CATEGORY_UTM) {
      return 'UTM 分带';
    }
    if (category === CRS_CATEGORY_WORLD_PROJECTED) {
      return '世界投影';
    }
    return '地理坐标系';
  }

  private categoryDescription(category: number): string {
    if (category === CRS_CATEGORY_CHINA_PROJECTED) {
      return 'CGCS2000 高斯-克吕格投影坐标系';
    }
    if (category === CRS_CATEGORY_UTM) {
      return 'WGS 84 通用横轴墨卡托分带';
    }
    if (category === CRS_CATEGORY_WORLD_PROJECTED) {
      return 'Web、世界和极区投影坐标系';
    }
    return '以经纬度表示位置，坐标单位通常为度';
  }

  private visibleItems(): CrsCatalogItem[] {
    let items = this.catalogItems();
    let visible: CrsCatalogItem[] = [];
    let keyword = this.searchText.trim().toLowerCase();
    for (let i = 0; i < items.length; i++) {
      let item = items[i];
      if (item.category !== this.selectedCategory) {
        continue;
      }
      if (keyword.length > 0) {
        let searchSource = (item.code + ' ' + item.name + ' ' + item.detail).toLowerCase();
        if (searchSource.indexOf(keyword) < 0) {
          continue;
        }
      }
      visible.push(item);
    }
    return visible;
  }

  private isSelected(item: CrsCatalogItem): boolean {
    return this.currentDefinition.trim().toUpperCase() === item.code;
  }

  private chooseItem(item: CrsCatalogItem): void {
    this.onSelected(item.code);
    this.isShow = false;
  }

  @Builder
  categoryItem(category: number, icon: Resource) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 10 }) {
        SymbolGlyph(icon)
          .fontSize(18)
          .fontColor([this.selectedCategory === category ? $r('app.color.gn_blue_800') :
            $r('sys.color.icon_secondary')])
        Text(this.categoryName(category))
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
    .padding({ left: 12, right: 10 })
    .backgroundColor(this.selectedCategory === category ? $r('app.color.gn_arc_active') : Color.Transparent)
    .borderRadius(7)
    .onClick(() => {
      this.selectedCategory = category;
      this.searchText = '';
    })
  }

  @Builder
  crsItem(item: CrsCatalogItem) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Row({ space: 8 }) {
            Text(item.code)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.gn_blue_800'))
            Text(item.isGeographic ? '地理坐标系' : '投影坐标系')
              .fontSize(10)
              .fontColor(item.isGeographic ? $r('app.color.gn_green_700') :
                $r('app.color.gn_orange_700'))
              .padding({ left: 7, right: 7, top: 2, bottom: 2 })
              .backgroundColor(item.isGeographic ? $r('app.color.gn_selected_row') :
                $r('app.color.gn_warning_bg'))
              .borderRadius(9)
          }
          .width('100%')
          Text(item.name)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.gn_text_primary'))
            .width('100%')
            .textAlign(TextAlign.Start)
          Text(item.detail)
            .fontSize(11)
            .fontColor($r('app.color.gn_text_muted'))
            .width('100%')
            .textAlign(TextAlign.Start)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        if (this.isSelected(item)) {
          SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
            .fontSize(22)
            .fontColor([$r('app.color.gn_blue_800')])
        } else {
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(16)
            .fontColor([$r('sys.color.icon_secondary')])
        }
      }
      .width('100%')
    }
    .width('100%')
    .height(82)
    .padding({ left: 14, right: 14 })
    .backgroundColor(this.isSelected(item) ? $r('app.color.gn_blue_100') : $r('app.color.gn_paper'))
    .borderRadius(7)
    .border({
      width: 1,
      color: this.isSelected(item) ? $r('app.color.gn_blue_800') : $r('app.color.gn_line')
    })
    .onClick(() => {
      this.chooseItem(item);
    })
  }

  @Builder
  sheetContent() {
    Column() {
      HdsNavigation() {
        Row() {
          Column({ space: 4 }) {
            Text('坐标系分类')
              .fontSize(11)
              .fontColor($r('app.color.gn_text_muted'))
              .width('100%')
              .padding({ left: 12, bottom: 8 })
            this.categoryItem(CRS_CATEGORY_GEOGRAPHIC, $r('sys.symbol.map'))
            this.categoryItem(CRS_CATEGORY_CHINA_PROJECTED, $r('sys.symbol.map'))
            this.categoryItem(CRS_CATEGORY_UTM, $r('sys.symbol.square_grid_2x2'))
            this.categoryItem(CRS_CATEGORY_WORLD_PROJECTED, $r('sys.symbol.map_badge_local'))
            Blank()
            Text('选择后仍会通过 QGIS 校验坐标系定义。')
              .fontSize(10)
              .fontColor($r('app.color.gn_text_muted'))
              .width('100%')
              .padding(12)
          }
          .width(200)
          .height('100%')
          .padding({ top: 16, bottom: 12, left: 10, right: 10 })
          .backgroundColor($r('app.color.gn_pane'))
          .border({ width: { right: 1 }, color: $r('app.color.gn_line') })

          Column({ space: 12 }) {
            Column({ space: 3 }) {
              Text(this.categoryName(this.selectedCategory))
                .fontSize(19)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.gn_text_primary'))
                .width('100%')
              Text(this.categoryDescription(this.selectedCategory))
                .fontSize(11)
                .fontColor($r('app.color.gn_text_muted'))
                .width('100%')
            }
            TextInput({ text: this.searchText, placeholder: '搜索 EPSG 编号或坐标系名称' })
              .height(38)
              .fontSize(13)
              .backgroundColor($r('app.color.gn_pane'))
              .onChange((value: string) => {
                this.searchText = value;
              })
            List({ space: 8 }) {
              ForEach(this.visibleItems(), (item: CrsCatalogItem) => {
                ListItem() {
                  this.crsItem(item)
                }
              }, (item: CrsCatalogItem) => item.code)
            }
            .layoutWeight(1)
            .width('100%')
            .scrollBar(BarState.Auto)
          }
          .layoutWeight(1)
          .height('100%')
          .padding({ left: 18, right: 18, top: 16, bottom: 16 })
        }
        .width('100%')
        .height('100%')
      }
      .mode(NavigationMode.Stack)
      .titleMode(HdsNavigationTitleMode.MODAL)
      .titleBar({
        content: {
          title: {
            mainTitle: '选择坐标系',
            subTitle: '明确区分地理坐标系与投影坐标系'
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
    }
    .width('100%')
    .height('100%')
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
        showClose: false,
        onDisappear: (): void => {
          this.isShow = false;
        }
      })
  }
}
