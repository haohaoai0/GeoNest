import { WorkbenchToolAction } from '../constants/WorkbenchConstants';
import { WorkbenchSearchViewModel } from '../viewmodel/WorkbenchSearchViewModel';

@Component
export struct WorkbenchToolsPanel {
  @Prop searchText: string = '';
  @Prop itemRadius: number = 6;
  onSearchTextChanged: (value: string) => void = (value: string): void => {};
  onAction: (actionId: number) => void = (actionId: number): void => {};
  private searchViewModel: WorkbenchSearchViewModel = new WorkbenchSearchViewModel();

  private matches(sourceText: string): boolean {
    let keyword: string = this.searchViewModel.normalizedText(this.searchText);
    return this.searchViewModel.matches(keyword, sourceText);
  }

  private allToolSearchText(): string {
    return 'qgis core gis内核 矢量编辑 属性编辑 标注系统 栅格显示 地图出图 裁剪 缓冲区 ' +
      '修复几何 数据质检 拓扑质检 错误图层 导出 定义投影 投影转换 简化几何 融合全部 生成质心 凸包 外包框 最小旋转外包框 ' +
      '多部件转单部件 按表达式提取 差集 对称差集 合并图层 多环缓冲 按位置提取 空间连接汇总 ' +
      '相交 最近邻 泰森多边形 核密度 点密度 线密度 IDW 插值 热力图 processing 算法浏览器 算法目录 打印出图 ' +
      'layout print raster processing overlay geometry analysis kernel density point density line density idw ' +
      'interpolation kde heatmap';
  }

  @Builder
  symbol(icon: Resource, color: ResourceColor, sizeValue: number) {
    SymbolGlyph(icon)
      .fontSize(sizeValue)
      .fontColor([color])
  }

  @Builder
  emptyState() {
    Column({ space: 6 }) {
      this.symbol($r('sys.symbol.magnifyingglass'), $r('sys.color.icon_secondary'), 22)
      Text('未找到匹配工具')
        .fontSize(12)
        .fontColor($r('app.color.gn_text_primary'))
      Text(this.searchText)
        .fontSize(11)
        .fontColor($r('app.color.gn_text_muted'))
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 24, bottom: 24 })
  }

  @Builder
  searchableItem(label: ResourceStr, description: ResourceStr, icon: Resource, actionId: number,
    sourceText: string) {
    if (this.matches(sourceText)) {
      this.toolItem(label, description, icon, actionId)
    }
  }

  @Builder
  toolItem(label: ResourceStr, description: ResourceStr, icon: Resource, actionId: number) {
    Row({ space: 10 }) {
      this.symbol(icon, $r('app.color.gn_blue_800'), 20)
      Column() {
        Text(label)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary'))
        Text(description)
          .fontSize(11)
          .fontColor($r('app.color.gn_text_muted'))
          .margin({ top: 3 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .height(58)
    .padding({ left: 12, right: 10 })
    .margin({ left: 8, right: 8, top: 4 })
    .borderRadius(this.itemRadius)
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: { bottom: 1 }, color: $r('app.color.gn_line') })
    .onClick(() => {
      this.onAction(actionId);
    })
  }

  build() {
    Column() {
      Search({ placeholder: $r('app.string.gn_workbench_tool_search') })
        .height(30)
        .margin({ left: 8, right: 8, bottom: 6 })
        .backgroundColor($r('app.color.gn_paper'))
        .onChange((value: string) => {
          this.onSearchTextChanged(value);
        })
      Scroll() {
        Column() {
          if (this.searchText.trim().length > 0 && !this.matches(this.allToolSearchText())) {
            this.emptyState()
          } else {
            this.searchableItem($r('app.string.gn_qgis_core_title'), $r('app.string.gn_qgis_core_desc'),
              $r('sys.symbol.wrench_arrow_counterclockwise'), WorkbenchToolAction.QGIS_CORE,
              'qgis core gis内核 核心')
            this.searchableItem($r('app.string.gn_processing_browser_title'),
              $r('app.string.gn_processing_browser_desc'), $r('sys.symbol.list_bullet_square'),
              WorkbenchToolAction.PROCESSING_BROWSER, 'processing 算法浏览器 算法目录 algorithm browser')
            this.searchableItem('矢量编辑', '新增点线面、节点移动删除、复制、撤销重做、吸附入口',
              $r('sys.symbol.wrench_arrow_counterclockwise'), WorkbenchToolAction.VECTOR_EDIT,
              '矢量编辑 新增点线面 节点 移动 删除 复制 撤销 重做 吸附 vector edit')
            this.searchableItem('属性编辑', '字段值修改、批量赋值、字段增删和字段计算器',
              $r('sys.symbol.doc_text'), WorkbenchToolAction.ATTRIBUTE_EDIT,
              '属性编辑 字段值 修改 批量赋值 字段 增删 字段计算器 attribute edit')
            this.searchableItem('标注系统', '字段标注、样式、避让、比例尺控制和开关',
              $r('sys.symbol.doc_text'), WorkbenchToolAction.LABELING,
              '标注系统 字段标注 样式 避让 比例尺 控制 labeling label')
            this.searchableItem('栅格显示', '单波段、RGB、拉伸、NoData、色带和阴影地形配置',
              $r('sys.symbol.map'), WorkbenchToolAction.RASTER_DISPLAY,
              '栅格显示 单波段 rgb 拉伸 nodata 色带 阴影地形 raster display')
            this.searchableItem('地图出图', '布局标题、图例、比例尺、指北针、坐标网和导出格式',
              $r('sys.symbol.doc_text'), WorkbenchToolAction.LAYOUT,
              '地图出图 布局 标题 图例 比例尺 指北针 坐标网 导出 layout')
            this.searchableItem($r('app.string.gn_cmd_clip'), $r('app.string.gn_tool_runner_desc'),
              $r('sys.symbol.square_dashed_and_arrow_turn_up_right'), WorkbenchToolAction.CLIP, '裁剪 clip')
            this.searchableItem($r('app.string.gn_cmd_buffer'), $r('app.string.gn_workbench_buffer_desc'),
              $r('sys.symbol.circle_grid_2x2'), WorkbenchToolAction.BUFFER, '缓冲区 缓冲 buffer')
            this.searchableItem($r('app.string.gn_cmd_repair'), $r('app.string.gn_workbench_repair_desc'),
              $r('sys.symbol.wrench_arrow_counterclockwise'), WorkbenchToolAction.REPAIR,
              '修复 修复几何 repair geometry')
            this.searchableItem($r('app.string.gn_cmd_quality_check'), $r('app.string.gn_tool_quality_check_desc'),
              $r('sys.symbol.list_checkmark'), WorkbenchToolAction.QUALITY_CHECK,
              '数据质检 质检 拓扑 错误图层 重复点 面重叠 悬挂线 字段缺失 quality topology check reviewer')
            this.searchableItem($r('app.string.gn_cmd_export'), $r('app.string.gn_workbench_export_desc'),
              $r('sys.symbol.download'), WorkbenchToolAction.EXPORT, '导出 导出成果 export download shapefile')
            this.searchableItem($r('app.string.gn_cmd_define_projection'),
              $r('app.string.gn_workbench_define_projection_desc'), $r('sys.symbol.map'),
              WorkbenchToolAction.DEFINE_PROJECTION, '定义投影 坐标系 crs projection define')
            this.searchableItem($r('app.string.gn_cmd_project_layer'),
              $r('app.string.gn_workbench_project_layer_desc'), $r('sys.symbol.arrow_right_and_square'),
              WorkbenchToolAction.PROJECT_LAYER, '投影转换 坐标转换 project layer transform')
            this.searchableItem($r('app.string.gn_cmd_simplify'), $r('app.string.gn_workbench_simplify_desc'),
              $r('sys.symbol.arrow_down_right_and_arrow_up_left'), WorkbenchToolAction.SIMPLIFY,
              '简化几何 简化 simplify')
            this.searchableItem($r('app.string.gn_cmd_dissolve'), $r('app.string.gn_workbench_dissolve_desc'),
              $r('sys.symbol.square_and_square'), WorkbenchToolAction.DISSOLVE, '融合全部 融合 dissolve')
            this.searchableItem($r('app.string.gn_cmd_centroid'), $r('app.string.gn_workbench_centroid_desc'),
              $r('sys.symbol.location_up'), WorkbenchToolAction.CENTROID, '生成质心 质心 centroid')
            this.searchableItem($r('app.string.gn_cmd_convex_hull'),
              $r('app.string.gn_workbench_convex_hull_desc'), $r('sys.symbol.layer'),
              WorkbenchToolAction.CONVEX_HULL, '凸包 convex hull')
            this.searchableItem($r('app.string.gn_cmd_bounding_boxes'),
              $r('app.string.gn_workbench_bounding_boxes_desc'), $r('sys.symbol.layer'),
              WorkbenchToolAction.BOUNDING_BOXES, '外包框 bounding boxes envelope')
            this.searchableItem($r('app.string.gn_cmd_oriented_minimum_bounding_box'),
              $r('app.string.gn_workbench_oriented_minimum_bounding_box_desc'), $r('sys.symbol.layer'),
              WorkbenchToolAction.ORIENTED_MINIMUM_BOUNDING_BOX,
              '最小旋转外包框 旋转外包框 oriented minimum bounding box ombb')
            this.searchableItem($r('app.string.gn_cmd_multipart_to_singleparts'),
              $r('app.string.gn_workbench_multipart_to_singleparts_desc'), $r('sys.symbol.square_stack_3d'),
              WorkbenchToolAction.MULTIPART_TO_SINGLEPARTS, '多部件转单部件 multipart singleparts')
            this.searchableItem($r('app.string.gn_cmd_extract_by_expression'),
              $r('app.string.gn_workbench_extract_by_expression_desc'), $r('sys.symbol.funnel'),
              WorkbenchToolAction.EXTRACT_BY_EXPRESSION, '按表达式提取 表达式 extract by expression')
            this.searchableItem($r('app.string.gn_expression_workbench_title'),
              $r('app.string.gn_expression_workbench_desc'), $r('sys.symbol.calculator'),
              WorkbenchToolAction.EXPRESSION_WORKBENCH,
              '表达式 工作台 字段计算 条件筛选 批量赋值 expression workbench')
            this.searchableItem($r('app.string.gn_cmd_difference'),
              $r('app.string.gn_workbench_difference_desc'), $r('sys.symbol.square_and_cut'),
              WorkbenchToolAction.DIFFERENCE, '差集 difference erase')
            this.searchableItem($r('app.string.gn_cmd_symmetrical_difference'),
              $r('app.string.gn_workbench_symmetrical_difference_desc'), $r('sys.symbol.square_and_square'),
              WorkbenchToolAction.SYMMETRICAL_DIFFERENCE, '对称差集 symmetrical difference symdiff')
            this.searchableItem($r('app.string.gn_cmd_merge_layers'),
              $r('app.string.gn_workbench_merge_layers_desc'), $r('sys.symbol.plus_square_on_square'),
              WorkbenchToolAction.MERGE_LAYERS, '合并图层 merge layers')
            this.searchableItem($r('app.string.gn_cmd_multi_ring_buffer'),
              $r('app.string.gn_workbench_multi_ring_buffer_desc'), $r('sys.symbol.circle_grid_2x2'),
              WorkbenchToolAction.MULTI_RING_BUFFER, '多环缓冲 multi ring buffer')
            this.searchableItem($r('app.string.gn_cmd_extract_by_location'),
              $r('app.string.gn_workbench_extract_by_location_desc'), $r('sys.symbol.location_up'),
              WorkbenchToolAction.EXTRACT_BY_LOCATION, '按位置提取 extract by location select by location')
            this.searchableItem($r('app.string.gn_cmd_spatial_join_summary'),
              $r('app.string.gn_workbench_spatial_join_summary_desc'), $r('sys.symbol.plus_square_on_square'),
              WorkbenchToolAction.SPATIAL_JOIN_SUMMARY, '空间连接汇总 空间连接 spatial join summary')
            this.searchableItem($r('app.string.gn_cmd_intersection'),
              $r('app.string.gn_workbench_intersection_desc'), $r('sys.symbol.square_and_square'),
              WorkbenchToolAction.INTERSECTION, '相交 intersection intersect')
            this.searchableItem($r('app.string.gn_cmd_nearest_neighbor'),
              $r('app.string.gn_workbench_nearest_neighbor_desc'), $r('sys.symbol.location_up'),
              WorkbenchToolAction.NEAREST_NEIGHBOR, '最近邻 nearest neighbor nearest')
            this.searchableItem($r('app.string.gn_cmd_voronoi'), $r('app.string.gn_workbench_voronoi_desc'),
              $r('sys.symbol.circle_grid_2x2'), WorkbenchToolAction.VORONOI, '泰森多边形 voronoi')
            this.searchableItem('核密度', '按搜索半径生成点核密度栅格', $r('sys.symbol.location_up'),
              WorkbenchToolAction.KERNEL_DENSITY, '核密度 kernel density kde heatmap 热力图 热点分析')
            this.searchableItem('点密度', '统计邻域点权重并生成密度栅格', $r('sys.symbol.location_up'),
              WorkbenchToolAction.POINT_DENSITY, '点密度 point density density raster 点密度分析')
            this.searchableItem('线密度', '统计邻域线段长度并生成密度栅格', $r('sys.symbol.location_up'),
              WorkbenchToolAction.LINE_DENSITY, '线密度 line density density raster 线密度分析')
            this.searchableItem('IDW 插值', '从点数值字段生成反距离权重插值栅格', $r('sys.symbol.location_up'),
              WorkbenchToolAction.IDW, 'idw 插值 inverse distance weighted interpolation raster')
            this.searchableItem('坡度', '从 DEM 第一波段生成坡度栅格', $r('sys.symbol.map'),
              WorkbenchToolAction.RASTER_SLOPE, '坡度 slope dem terrain raster 地形分析')
            this.searchableItem('坡向', '从 DEM 第一波段生成坡向栅格', $r('sys.symbol.location_up'),
              WorkbenchToolAction.RASTER_ASPECT, '坡向 aspect dem terrain raster 地形分析')
            this.searchableItem('栅格重分类', '按区间规则重分类栅格值', $r('sys.symbol.square_stack_3d'),
              WorkbenchToolAction.RASTER_RECLASSIFY, '栅格重分类 reclass reclassify raster remap 分类')
            this.searchableItem('打印出图', '页面尺寸、比例尺、图例、指北针和导出 PDF', $r('sys.symbol.printer'),
              WorkbenchToolAction.PRINT, '打印出图 打印 pdf print')
          }
          Blank()
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
    }
    .layoutWeight(1)
  }
}
