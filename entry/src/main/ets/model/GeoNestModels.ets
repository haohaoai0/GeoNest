export class ParcelRow {
  objectId: string = '';
  landId: string = '';
  landType: string = '';
  area: string = '';
  owner: string = '';
  status: string = '';
  updateTime: string = '';
  statusType: number = 0;

  constructor(objectId: string, landId: string, landType: string, area: string, owner: string, status: string,
    updateTime: string, statusType: number) {
    this.objectId = objectId;
    this.landId = landId;
    this.landType = landType;
    this.area = area;
    this.owner = owner;
    this.status = status;
    this.updateTime = updateTime;
    this.statusType = statusType;
  }
}

export class DataAsset {
  title: string = '';
  meta: string = '';
  status: string = '';
  kind: number = 0;

  constructor(title: string, meta: string, status: string, kind: number) {
    this.title = title;
    this.meta = meta;
    this.status = status;
    this.kind = kind;
  }
}

export class QualityIssue {
  title: string = '';
  description: string = '';
  level: number = 0;
  count: string = '';

  constructor(title: string, description: string, level: number, count: string) {
    this.title = title;
    this.description = description;
    this.level = level;
    this.count = count;
  }
}

export class ToolAction {
  title: string = '';
  description: string = '';
  kind: number = 0;

  constructor(title: string, description: string, kind: number) {
    this.title = title;
    this.description = description;
    this.kind = kind;
  }
}

export class GeoNestProjectParameters {
  name: string = '';
  owner: string = '';
  crs: string = '';
  mapName: string = '';
  workspaceName: string = '';
  description: string = '';

  constructor(name: string, owner: string, crs: string, mapName: string, workspaceName: string,
    description: string) {
    this.name = name;
    this.owner = owner;
    this.crs = crs;
    this.mapName = mapName;
    this.workspaceName = workspaceName;
    this.description = description;
  }
}

export class RecentProjectRecord {
  uri: string = '';
  name: string = '';
  owner: string = '';
  crs: string = '';
  workspaceName: string = '';

  constructor(uri: string, name: string, owner: string, crs: string, workspaceName: string) {
    this.uri = uri;
    this.name = name;
    this.owner = owner;
    this.crs = crs;
    this.workspaceName = workspaceName;
  }
}

export function createParcelRows(): ParcelRow[] {
  return [
    new ParcelRow('1017', 'A-017', '仓储用地', '9,780', '北田物流园', '通过', '2026-06-18', 0),
    new ParcelRow('1042', 'A-042', '工业用地', '18,420', '晋中开发区管委会', '边界待复核', '2026-06-19', 1),
    new ParcelRow('1103', 'B-103', '公共设施', '6,360', '榆次区住建局', '属性待补', '2026-06-20', 1),
    new ParcelRow('2011', 'C-011', '居住用地', '14,960', '新城社区', '通过', '2026-06-18', 0),
    new ParcelRow('2079', 'D-079', '耕地保护', '21,310', '郭家堡乡', '重叠错误', '2026-06-20', 2),
    new ParcelRow('2126', 'D-126', '商业服务', '8,240', '汇通街道办', '通过', '2026-06-17', 0)
  ];
}

export function createDataAssets(): DataAsset[] {
  return [
    new DataAsset('Yuci_landuse.gpkg', 'GeoPackage · 96.8 MB · 1,268 features', '已同步', 0),
    new DataAsset('road_centerline.shp', 'Shapefile · UTF-8 · 426 features', '本地更新', 1),
    new DataAsset('dom_2025_yuci.tif', 'Raster · 0.5 m · 4 bands', '只读', 2),
    new DataAsset('quality_errors.csv', 'Standalone table · 7 records', '待处理', 3)
  ];
}

export function createQualityIssues(): QualityIssue[] {
  return [
    new QualityIssue('面重叠检查', 'D-079 与规划分区存在 3 处重叠', 2, '3'),
    new QualityIssue('属性值域检查', '地类代码与权属字段存在缺失', 1, '4'),
    new QualityIssue('坐标系一致性', '所有图层已通过 EPSG:4547 校验', 0, '通过'),
    new QualityIssue('几何修复', '已修复 18 条自相交边界', 0, '完成')
  ];
}

export function createToolActions(): ToolAction[] {
  return [
    new ToolAction('裁剪', '用规划分区裁剪建设用地面，输出核查工作图层。', 0),
    new ToolAction('缓冲区', '按道路中心线生成建设退距辅助分析范围。', 1),
    new ToolAction('修复几何', '批量修复自相交、空几何和重复节点。', 2),
    new ToolAction('导出成果', '生成 A1 成果图和质检报告附件。', 3)
  ];
}

export class GisEnvelope {
  minX: number = 0;
  minY: number = 0;
  maxX: number = 0;
  maxY: number = 0;

  constructor(minX: number, minY: number, maxX: number, maxY: number) {
    this.minX = minX;
    this.minY = minY;
    this.maxX = maxX;
    this.maxY = maxY;
  }
}

export class GisCrsInfo {
  ok: boolean = false;
  code: number = 0;
  message: string = '';
  input: string = '';
  isValid: boolean = false;
  authId: string = '';
  description: string = '';
  friendlyName: string = '';
  projectionAcronym: string = '';
  ellipsoidAcronym: string = '';
  geographicCrsAuthId: string = '';
  celestialBodyName: string = '';
  isGeographic: boolean = false;
  hasAxisInverted: boolean = false;
  srsId: number = 0;
  postgisSrid: number = 0;
  mapUnitCode: number = 0;
  unitName: string = '';
  unitType: number = 0;
  bounds: GisEnvelope = new GisEnvelope(0, 0, 0, 0);
  proj: string = '';
  wkt: string = '';

  constructor(ok: boolean, code: number, message: string, input: string) {
    this.ok = ok;
    this.code = code;
    this.message = message;
    this.input = input;
  }
}

export class GisCoordinateTransformResult {
  ok: boolean = false;
  code: number = 0;
  message: string = '';
  x: number = 0;
  y: number = 0;
  sourceAuthId: string = '';
  targetAuthId: string = '';

  constructor(ok: boolean, code: number, message: string, x: number, y: number) {
    this.ok = ok;
    this.code = code;
    this.message = message;
    this.x = x;
    this.y = y;
  }
}

export class GisEnvelopeTransformResult {
  ok: boolean = false;
  code: number = 0;
  message: string = '';
  envelope: GisEnvelope = new GisEnvelope(0, 0, 0, 0);
  sourceAuthId: string = '';
  targetAuthId: string = '';

  constructor(ok: boolean, code: number, message: string, envelope: GisEnvelope) {
    this.ok = ok;
    this.code = code;
    this.message = message;
    this.envelope = envelope;
  }
}

export class GisFieldInfo {
  name: string = '';
  alias: string = '';
  typeName: string = '';
  width: number = 0;
  precision: number = 0;
  nullable: boolean = true;

  constructor(name: string, alias: string, typeName: string, width: number, precision: number, nullable: boolean) {
    this.name = name;
    this.alias = alias;
    this.typeName = typeName;
    this.width = width;
    this.precision = precision;
    this.nullable = nullable;
  }
}

export class GisAttributeValue {
  name: string = '';
  typeName: string = '';
  textValue: string = '';
  numberValue: number = 0;
  boolValue: boolean = false;
  isNull: boolean = false;

  constructor(name: string, typeName: string, textValue: string, numberValue: number, boolValue: boolean,
    isNull: boolean) {
    this.name = name;
    this.typeName = typeName;
    this.textValue = textValue;
    this.numberValue = numberValue;
    this.boolValue = boolValue;
    this.isNull = isNull;
  }
}

export class GisCoordinate {
  x: number = 0;
  y: number = 0;
  z: number = 0;
  hasZ: boolean = false;

  constructor(x: number, y: number, z: number, hasZ: boolean) {
    this.x = x;
    this.y = y;
    this.z = z;
    this.hasZ = hasZ;
  }
}

export class GisGeometryPart {
  points: GisCoordinate[] = [];

  constructor(points: GisCoordinate[]) {
    this.points = points;
  }
}

export class GisGeometryPayload {
  geometryType: number = 0;
  parts: GisGeometryPart[] = [];
  envelope: GisEnvelope = new GisEnvelope(0, 0, 0, 0);
  crs: string = '';

  constructor(geometryType: number, parts: GisGeometryPart[], envelope: GisEnvelope, crs: string) {
    this.geometryType = geometryType;
    this.parts = parts;
    this.envelope = envelope;
    this.crs = crs;
  }
}

export class GisLayerInfo {
  layerId: string = '';
  name: string = '';
  geometryType: number = 0;
  featureCount: number = 0;
  envelope: GisEnvelope = new GisEnvelope(0, 0, 0, 0);
  crs: string = '';
  crsDescription: string = '';
  crsFriendlyName: string = '';
  projectionAcronym: string = '';
  ellipsoidAcronym: string = '';
  geographicCrsAuthId: string = '';
  crsIsGeographic: boolean = false;
  crsBounds: GisEnvelope = new GisEnvelope(0, 0, 0, 0);
  coordinateUnitName: string = '';
  coordinateUnitType: number = 0;
  legendColor: string = '';
  legendStrokeColor: string = '';
  fields: GisFieldInfo[] = [];

  constructor(layerId: string, name: string, geometryType: number, featureCount: number, envelope: GisEnvelope,
    crs: string, fields: GisFieldInfo[]) {
    this.layerId = layerId;
    this.name = name;
    this.geometryType = geometryType;
    this.featureCount = featureCount;
    this.envelope = envelope;
    this.crs = crs;
    this.fields = fields;
  }
}

export class GisFeatureSummary {
  featureId: string = '';
  geometry: GisGeometryPayload = new GisGeometryPayload(0, [], new GisEnvelope(0, 0, 0, 0), '');
  envelope: GisEnvelope = new GisEnvelope(0, 0, 0, 0);
  attributesPreview: GisAttributeValue[] = [];

  constructor(featureId: string, geometry: GisGeometryPayload, envelope: GisEnvelope,
    attributesPreview: GisAttributeValue[]) {
    this.featureId = featureId;
    this.geometry = geometry;
    this.envelope = envelope;
    this.attributesPreview = attributesPreview;
  }
}

export class GisFeaturePage {
  layerId: string = '';
  features: GisFeatureSummary[] = [];
  hasMore: boolean = false;

  constructor(layerId: string, features: GisFeatureSummary[], hasMore: boolean) {
    this.layerId = layerId;
    this.features = features;
    this.hasMore = hasMore;
  }
}

export class GisOperationResult {
  ok: boolean = false;
  code: number = 0;
  message: string = '';

  constructor(ok: boolean, code: number, message: string) {
    this.ok = ok;
    this.code = code;
    this.message = message;
  }
}

export class GisGeoProcessResult {
  ok: boolean = false;
  code: number = 0;
  message: string = '';
  outputPath: string = '';
  outputLayerName: string = '';
  featureCount: number = 0;

  constructor(ok: boolean, code: number, message: string, outputPath: string, outputLayerName: string,
    featureCount: number) {
    this.ok = ok;
    this.code = code;
    this.message = message;
    this.outputPath = outputPath;
    this.outputLayerName = outputLayerName;
    this.featureCount = featureCount;
  }
}

export function createEmptyGisEnvelope(): GisEnvelope {
  return new GisEnvelope(0, 0, 0, 0);
}
