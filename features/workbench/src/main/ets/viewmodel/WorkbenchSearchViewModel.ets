import { WorkbenchTextService } from '../service/WorkbenchTextService';
import { GlobalSearchCandidate } from '../model/WorkbenchModels';
import {
  ACTION_ADD_DATA,
  ACTION_ATTRIBUTE_TABLE,
  ACTION_FULL_EXTENT,
  ACTION_HELP,
  ACTION_NEW_PROJECT,
  ACTION_OPEN_PROJECT,
  ACTION_PROJECT_INFO,
  ACTION_SAVE_PROJECT,
  ACTION_SETTINGS,
  ACTION_SYMBOLOGY,
  ACTION_ZOOM_IN,
  ACTION_ZOOM_OUT,
  WorkbenchSearchCandidateKind,
  WorkbenchToolAction
} from '../constants/WorkbenchConstants';

export class WorkbenchSearchViewModel {
  normalizedText(value: string): string {
    return WorkbenchTextService.normalizedSearchText(value);
  }

  compactText(value: string): string {
    return WorkbenchTextService.compactSearchText(value);
  }

  matches(keyword: string, sourceText: string): boolean {
    return WorkbenchTextService.searchMatches(keyword, sourceText);
  }

  private addCommandSearchCandidate(items: GlobalSearchCandidate[], title: string, subtitle: string, category: string,
    actionId: number, sourceText: string): void {
    let item: GlobalSearchCandidate = new GlobalSearchCandidate();
    item.kind = WorkbenchSearchCandidateKind.COMMAND;
    item.key = 'cmd:' + actionId.toString();
    item.title = title;
    item.subtitle = subtitle;
    item.category = category;
    item.actionId = actionId;
    item.sourceText = title + ' ' + subtitle + ' ' + category + ' ' + sourceText;
    items.push(item);
  }

  private buildCommandSearchCandidatePool(): GlobalSearchCandidate[] {
    let items: GlobalSearchCandidate[] = [];
    this.addCommandSearchCandidate(items, '新建工程', '创建新的 GeoNest 工程', '工程', ACTION_NEW_PROJECT,
      '新建 创建 create new project');
    this.addCommandSearchCandidate(items, '打开工程', '打开本地 GeoNest 或 QGIS 工程', '工程', ACTION_OPEN_PROJECT,
      '打开 open project qgs qgz gnproj');
    this.addCommandSearchCandidate(items, '保存工程', '保存当前工程', '工程', ACTION_SAVE_PROJECT,
      '保存 save project');
    this.addCommandSearchCandidate(items, '工程信息', '查看和编辑项目基本信息', '工程', ACTION_PROJECT_INFO,
      '工程信息 项目信息 project info metadata');
    this.addCommandSearchCandidate(items, '添加数据', '导入 Shapefile 等 GIS 数据', '图层', ACTION_ADD_DATA,
      '添加数据 导入 图层 shp shapefile add data import');
    this.addCommandSearchCandidate(items, '属性表', '打开当前图层属性表', '图层', ACTION_ATTRIBUTE_TABLE,
      '属性表 attribute table fields rows');
    this.addCommandSearchCandidate(items, '符号系统', '设置图层样式和符号', '图层', ACTION_SYMBOLOGY,
      '符号系统 符号 样式 symbology symbol style');
    this.addCommandSearchCandidate(items, '裁剪', '按范围或图层裁剪要素', '分析工具', WorkbenchToolAction.CLIP,
      '裁剪 clip extract mask');
    this.addCommandSearchCandidate(items, '缓冲区', '生成点线面缓冲区', '分析工具', WorkbenchToolAction.BUFFER,
      '缓冲区 缓冲 buffer distance');
    this.addCommandSearchCandidate(items, '修复几何', '修复图层几何错误', '分析工具', WorkbenchToolAction.REPAIR,
      '修复 修复几何 repair geometry fix');
    this.addCommandSearchCandidate(items, '数据质检', '生成拓扑和属性错误点图层', '分析工具', WorkbenchToolAction.QUALITY_CHECK,
      '数据质检 质检 拓扑 错误图层 重复点 面重叠 悬挂线 字段缺失 quality topology check reviewer');
    this.addCommandSearchCandidate(items, '导出成果', '导出当前图层或成果数据', '图层', WorkbenchToolAction.EXPORT,
      '导出 导出成果 export download shapefile');
    this.addCommandSearchCandidate(items, '定义投影', '为数据定义坐标参考系', '坐标系', WorkbenchToolAction.DEFINE_PROJECTION,
      '定义投影 坐标系 crs projection define');
    this.addCommandSearchCandidate(items, '投影转换', '转换图层坐标参考系', '坐标系', WorkbenchToolAction.PROJECT_LAYER,
      '投影转换 坐标转换 project layer transform crs');
    this.addCommandSearchCandidate(items, '简化几何', '简化线和面要素', '分析工具', WorkbenchToolAction.SIMPLIFY,
      '简化 简化几何 simplify generalize');
    this.addCommandSearchCandidate(items, '融合全部', '按字段或全部融合要素', '分析工具', WorkbenchToolAction.DISSOLVE,
      '融合 融合全部 dissolve merge');
    this.addCommandSearchCandidate(items, '生成质心', '从面或线生成质心点', '分析工具', WorkbenchToolAction.CENTROID,
      '质心 生成质心 centroid center');
    this.addCommandSearchCandidate(items, '凸包', '生成凸包面', '分析工具', WorkbenchToolAction.CONVEX_HULL,
      '凸包 convex hull');
    this.addCommandSearchCandidate(items, '外包框', '生成外接矩形', '分析工具', WorkbenchToolAction.BOUNDING_BOXES,
      '外包框 bounding boxes envelope extent rectangle');
    this.addCommandSearchCandidate(items, '最小旋转外包框', '生成方向最小外包框', '分析工具',
      WorkbenchToolAction.ORIENTED_MINIMUM_BOUNDING_BOX, '最小旋转外包框 旋转外包框 oriented minimum bounding box ombb');
    this.addCommandSearchCandidate(items, '多部件转单部件', '拆分 multipart 要素', '分析工具',
      WorkbenchToolAction.MULTIPART_TO_SINGLEPARTS, '多部件转单部件 multipart singleparts explode');
    this.addCommandSearchCandidate(items, '按表达式提取', '按表达式过滤并提取要素', '分析工具',
      WorkbenchToolAction.EXTRACT_BY_EXPRESSION, '按表达式提取 表达式 extract by expression filter');
    this.addCommandSearchCandidate(items, '差集', '计算输入图层与叠置图层差集', '分析工具', WorkbenchToolAction.DIFFERENCE,
      '差集 difference erase overlay');
    this.addCommandSearchCandidate(items, '对称差集', '保留两个图层非重叠区域', '分析工具',
      WorkbenchToolAction.SYMMETRICAL_DIFFERENCE, '对称差集 symmetrical difference symdiff overlay');
    this.addCommandSearchCandidate(items, '合并图层', '合并多个同类图层', '分析工具', WorkbenchToolAction.MERGE_LAYERS,
      '合并图层 merge layers append');
    this.addCommandSearchCandidate(items, '多环缓冲', '生成多距离环状缓冲区', '分析工具',
      WorkbenchToolAction.MULTI_RING_BUFFER, '多环缓冲 multi ring buffer distance');
    this.addCommandSearchCandidate(items, '按位置提取', '按空间关系提取要素', '分析工具',
      WorkbenchToolAction.EXTRACT_BY_LOCATION, '按位置提取 extract by location select by location spatial');
    this.addCommandSearchCandidate(items, '空间连接汇总', '按空间关系连接并统计字段', '分析工具',
      WorkbenchToolAction.SPATIAL_JOIN_SUMMARY, '空间连接汇总 空间连接 spatial join summary');
    this.addCommandSearchCandidate(items, '相交', '计算图层相交区域', '分析工具', WorkbenchToolAction.INTERSECTION,
      '相交 intersection intersect overlay');
    this.addCommandSearchCandidate(items, '最近邻', '查找最近要素', '分析工具', WorkbenchToolAction.NEAREST_NEIGHBOR,
      '最近邻 nearest neighbor nearest distance');
    this.addCommandSearchCandidate(items, '泰森多边形', '生成 Voronoi 多边形', '分析工具', WorkbenchToolAction.VORONOI,
      '泰森多边形 voronoi');
    this.addCommandSearchCandidate(items, '核密度', '按搜索半径生成点核密度栅格', '栅格分析',
      WorkbenchToolAction.KERNEL_DENSITY, '核密度 kernel density kde heatmap 热力图 热点分析');
    this.addCommandSearchCandidate(items, '点密度', '统计邻域点权重并生成密度栅格', '栅格分析',
      WorkbenchToolAction.POINT_DENSITY, '点密度 point density density raster 点密度分析');
    this.addCommandSearchCandidate(items, '线密度', '统计邻域线段长度并生成密度栅格', '栅格分析',
      WorkbenchToolAction.LINE_DENSITY, '线密度 line density polyline density raster 线密度分析');
    this.addCommandSearchCandidate(items, 'IDW 插值', '从点数值字段生成反距离权重插值栅格', '栅格分析',
      WorkbenchToolAction.IDW, 'idw 插值 反距离权重 inverse distance weighted interpolation raster');
    this.addCommandSearchCandidate(items, '坡度', '从 DEM 第一波段生成坡度栅格', '栅格分析',
      WorkbenchToolAction.RASTER_SLOPE, '坡度 slope dem terrain raster 地形分析');
    this.addCommandSearchCandidate(items, '坡向', '从 DEM 第一波段生成坡向栅格', '栅格分析',
      WorkbenchToolAction.RASTER_ASPECT, '坡向 aspect dem terrain raster 地形分析');
    this.addCommandSearchCandidate(items, '栅格重分类', '按区间规则重分类栅格值', '栅格分析',
      WorkbenchToolAction.RASTER_RECLASSIFY, '栅格重分类 reclass reclassify raster remap 分类');
    this.addCommandSearchCandidate(items, '表达式工作台', '字段计算、条件筛选、按表达式提取和批量赋值', '分析工具',
      WorkbenchToolAction.EXPRESSION_WORKBENCH, '表达式 工作台 字段计算 条件筛选 批量赋值 expression workbench calculator filter');
    this.addCommandSearchCandidate(items, '算法浏览器', '浏览 QGIS Processing 算法', '工具',
      WorkbenchToolAction.PROCESSING_BROWSER, 'processing 算法浏览器 算法目录 algorithm browser qgis');
    this.addCommandSearchCandidate(items, 'QGIS Core', '查看 GIS 内核状态', '工具', WorkbenchToolAction.QGIS_CORE,
      'qgis core gis内核 内核 qgis');
    this.addCommandSearchCandidate(items, '矢量编辑', '新增点线面和编辑节点', '编辑', WorkbenchToolAction.VECTOR_EDIT,
      '矢量编辑 新增 点 线 面 节点 移动 删除 复制 撤销 重做 吸附 vector edit');
    this.addCommandSearchCandidate(items, '属性编辑', '修改字段值和批量赋值', '编辑', WorkbenchToolAction.ATTRIBUTE_EDIT,
      '属性编辑 字段值 修改 批量赋值 字段计算器 attribute edit');
    this.addCommandSearchCandidate(items, '标注系统', '字段标注、样式和比例尺控制', '图层', WorkbenchToolAction.LABELING,
      '标注 标注系统 字段标注 样式 避让 比例尺 labeling label');
    this.addCommandSearchCandidate(items, '栅格显示', '配置栅格渲染和拉伸', '图层', WorkbenchToolAction.RASTER_DISPLAY,
      '栅格 栅格显示 单波段 rgb 拉伸 nodata 色带 raster display');
    this.addCommandSearchCandidate(items, '地图出图', '配置版面和导出地图', '出图', WorkbenchToolAction.LAYOUT,
      '地图出图 布局 标题 图例 比例尺 指北针 坐标网 导出 layout map');
    this.addCommandSearchCandidate(items, '打印出图', '页面尺寸、图例和 PDF 输出', '出图', WorkbenchToolAction.PRINT,
      '打印 打印出图 pdf print layout');
    this.addCommandSearchCandidate(items, '放大', '地图放大一级', '地图', ACTION_ZOOM_IN,
      '放大 zoom in map');
    this.addCommandSearchCandidate(items, '缩小', '地图缩小一级', '地图', ACTION_ZOOM_OUT,
      '缩小 zoom out map');
    this.addCommandSearchCandidate(items, '全图显示', '缩放到全部图层范围', '地图', ACTION_FULL_EXTENT,
      '全图 全图显示 full extent zoom');
    this.addCommandSearchCandidate(items, '设置', '打开应用设置', '系统', ACTION_SETTINGS,
      '设置 settings preference');
    this.addCommandSearchCandidate(items, '帮助', '打开帮助说明', '系统', ACTION_HELP,
      '帮助 help guide');
    return items;
  }



  buildCommandCandidates(keyword: string): GlobalSearchCandidate[] {
    let sourceItems: GlobalSearchCandidate[] = this.buildCommandSearchCandidatePool();
    let items: GlobalSearchCandidate[] = [];
    for (let i: number = 0; i < sourceItems.length; i++) {
      if (this.matches(keyword, sourceItems[i].sourceText)) {
        items.push(sourceItems[i]);
      }
    }
    return items;
  }

}
