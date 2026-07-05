import {
  getCoreProfile,
  getNativeVersion,
  getProcessingAlgorithms,
  executeProcessingAlgorithm,
  openVectorLayer,
  openRasterLayer,
  closeLayer,
  getLayerInfo,
  queryFeatures,
  getFeature,
  bufferLayer,
  simplifyLayer,
  dissolveLayer,
  centroidLayer,
  repairLayer,
  clipLayer,
  exportLayer,
  defineLayerProjection,
  projectLayer,
  applyVectorStyle,
  applyVectorLabeling,
  configureRasterDisplay,
  exportMapLayout,
  describeCoordinateReferenceSystem,
  transformCoordinate,
  transformEnvelope,
  addFeature,
  deleteFeature,
  moveFeatureNode,
  deleteFeatureNode,
  copyFeature,
  splitFeature,
  mergeFeatures,
  snapLayer,
  updateFeatureAttribute,
  batchAssignAttribute,
  addLayerField,
  deleteLayerField,
  calculateField,
  NativeLayerOpenResult,
  NativeLayerInfoResult,
  NativeFeaturePageResult,
  NativeFeatureResult,
  NativeGeoProcessResult
} from 'libgeonestgis.so';
import {
  GisLayerInfo,
  GisFieldInfo,
  GisEnvelope,
  GisFeaturePage,
  GisFeatureSummary,
  GisGeometryPayload,
  GisGeometryPart,
  GisCoordinate,
  GisAttributeValue,
  GisOperationResult,
  GisGeoProcessResult,
  GisCrsInfo,
  GisCoordinateTransformResult,
  GisEnvelopeTransformResult
} from '../model/GeoNestModels';
import hilog from '@ohos.hilog';

const BRIDGE_TAG: number = 0xFF01;
const BRIDGE_DOMAIN: string = 'GeoNest';

// ---------------------------------------------------------------------------
// Bridge status
// ---------------------------------------------------------------------------
export class GisNativeBridgeStatus {
  available: boolean = false;
  version: string = '';
  profile: string = '';

  constructor(available: boolean, version: string, profile: string) {
    this.available = available;
    this.version = version;
    this.profile = profile;
  }
}

export function queryGisNativeBridgeStatus(): GisNativeBridgeStatus {
  let version: string = '';
  let profile: string = '';

  try {
    version = getNativeVersion();
    profile = getCoreProfile();
  } catch (e) {
    return new GisNativeBridgeStatus(false, version, profile);
  }

  return new GisNativeBridgeStatus(true, version, profile);
}

// ---------------------------------------------------------------------------
// Simple JSON parser for ArkTS (avoids JSON.parse() which returns ESObject)
// Parses a JSON string into Map<string, Object> / Array<Object> / string / number / boolean
// ---------------------------------------------------------------------------

class JsonParser {
  private text: string = '';
  private pos: number = 0;

  parse(input: string): Object {
    this.text = input;
    this.pos = 0;
    this.skipWhitespace();
    return this.readValue();
  }

  private skipWhitespace(): void {
    while (this.pos < this.text.length) {
      let c = this.text.charAt(this.pos);
      if (c === ' ' || c === '\t' || c === '\n' || c === '\r') {
        this.pos++;
      } else {
        break;
      }
    }
  }

  private readValue(): Object {
    this.skipWhitespace();
    if (this.pos >= this.text.length) {
      return '';
    }
    let c = this.text.charAt(this.pos);
    if (c === '{') {
      return this.readObject();
    } else if (c === '[') {
      return this.readArray();
    } else if (c === '"') {
      return this.readString();
    } else if (c === 't' || c === 'f') {
      return this.readBoolean();
    } else if (c === 'n') {
      return this.readNull();
    } else {
      return this.readNumber();
    }
  }

  private readObject(): Map<string, Object> {
    let map = new Map<string, Object>();
    this.pos++; // skip '{'
    this.skipWhitespace();
    if (this.pos < this.text.length && this.text.charAt(this.pos) === '}') {
      this.pos++;
      return map;
    }
    while (this.pos < this.text.length) {
      this.skipWhitespace();
      let key = this.readString();
      this.skipWhitespace();
      this.pos++; // skip ':'
      this.skipWhitespace();
      let val = this.readValue();
      map.set(key, val);
      this.skipWhitespace();
      if (this.pos < this.text.length && this.text.charAt(this.pos) === ',') {
        this.pos++;
      } else {
        break;
      }
    }
    this.skipWhitespace();
    if (this.pos < this.text.length && this.text.charAt(this.pos) === '}') {
      this.pos++;
    }
    return map;
  }

  private readArray(): Array<Object> {
    let arr = new Array<Object>();
    this.pos++; // skip '['
    this.skipWhitespace();
    if (this.pos < this.text.length && this.text.charAt(this.pos) === ']') {
      this.pos++;
      return arr;
    }
    while (this.pos < this.text.length) {
      this.skipWhitespace();
      let val = this.readValue();
      arr.push(val);
      this.skipWhitespace();
      if (this.pos < this.text.length && this.text.charAt(this.pos) === ',') {
        this.pos++;
      } else {
        break;
      }
    }
    this.skipWhitespace();
    if (this.pos < this.text.length && this.text.charAt(this.pos) === ']') {
      this.pos++;
    }
    return arr;
  }

  private readString(): string {
    this.pos++; // skip opening '"'
    let result = '';
    while (this.pos < this.text.length) {
      let c = this.text.charAt(this.pos);
      if (c === '\\') {
        this.pos++;
        if (this.pos < this.text.length) {
          let esc = this.text.charAt(this.pos);
          if (esc === '"') result += '"';
          else if (esc === '\\') result += '\\';
          else if (esc === '/') result += '/';
          else if (esc === 'n') result += '\n';
          else if (esc === 'r') result += '\r';
          else if (esc === 't') result += '\t';
          else result += esc;
        }
      } else if (c === '"') {
        this.pos++;
        return result;
      } else {
        result += c;
      }
      this.pos++;
    }
    return result;
  }

  private readNumber(): number {
    let start = this.pos;
    if (this.pos < this.text.length && (this.text.charAt(this.pos) === '-' || this.text.charAt(this.pos) === '+')) {
      this.pos++;
    }
    while (this.pos < this.text.length) {
      let c = this.text.charAt(this.pos);
      if ((c >= '0' && c <= '9') || c === '.' || c === 'e' || c === 'E' || c === '+' || c === '-') {
        this.pos++;
      } else {
        break;
      }
    }
    let numStr = this.text.substring(start, this.pos);
    return Number(numStr);
  }

  private readBoolean(): boolean {
    if (this.text.charAt(this.pos) === 't') {
      let remaining = this.text.length - this.pos;
      if (remaining >= 4) this.pos += 4;
      else this.pos = this.text.length;
      return true;
    } else {
      let remaining = this.text.length - this.pos;
      if (remaining >= 5) this.pos += 5;
      else this.pos = this.text.length;
      return false;
    }
  }

  private readNull(): Object {
    let remaining = this.text.length - this.pos;
    if (remaining >= 4) this.pos += 4;
    else this.pos = this.text.length;
    return '';
  }
}

let jsonParser = new JsonParser();

function parseJsonString(json: string): Object {
  return jsonParser.parse(json);
}

// ---------------------------------------------------------------------------
// Map access helpers
// ---------------------------------------------------------------------------

function mapGetString(map: Map<string, Object>, key: string): string {
  let v = map.get(key);
  if (v !== undefined && v !== null) {
    return String(v);
  }
  return '';
}

function mapGetNumber(map: Map<string, Object>, key: string): number {
  let v = map.get(key);
  if (v !== undefined && v !== null) {
    return Number(v);
  }
  return 0;
}

function mapGetBool(map: Map<string, Object>, key: string): boolean {
  let v = map.get(key);
  if (v !== undefined && v !== null) {
    return Boolean(v);
  }
  return false;
}

// ---------------------------------------------------------------------------
// Parsing helpers
// ---------------------------------------------------------------------------

function parseEnvelope(raw: Map<string, Object>): GisEnvelope {
  let env: GisEnvelope = new GisEnvelope(0, 0, 0, 0);
  env.minX = mapGetNumber(raw, 'minX');
  env.minY = mapGetNumber(raw, 'minY');
  env.maxX = mapGetNumber(raw, 'maxX');
  env.maxY = mapGetNumber(raw, 'maxY');
  return env;
}

function parseFieldInfo(raw: Map<string, Object>): GisFieldInfo {
  let field: GisFieldInfo = new GisFieldInfo('', '', '', 0, 0, true);
  field.name = mapGetString(raw, 'name');
  field.alias = mapGetString(raw, 'alias');
  field.typeName = mapGetString(raw, 'typeName');
  field.width = mapGetNumber(raw, 'width');
  field.precision = mapGetNumber(raw, 'precision');
  field.nullable = mapGetBool(raw, 'nullable');
  return field;
}

function parseCoordinate(raw: Map<string, Object>): GisCoordinate {
  let coord: GisCoordinate = new GisCoordinate(0, 0, 0, false);
  coord.x = mapGetNumber(raw, 'x');
  coord.y = mapGetNumber(raw, 'y');
  coord.z = mapGetNumber(raw, 'z');
  coord.hasZ = mapGetBool(raw, 'hasZ');
  return coord;
}

function parseGeometry(raw: Map<string, Object>): GisGeometryPayload {
  let geom: GisGeometryPayload = new GisGeometryPayload(0, [], new GisEnvelope(0, 0, 0, 0), '');
  geom.geometryType = mapGetNumber(raw, 'geometryType');
  geom.crs = mapGetString(raw, 'crs');
  let envObj = raw.get('envelope');
  if (envObj !== undefined && envObj !== null) {
    geom.envelope = parseEnvelope(envObj as Map<string, Object>);
  }
  let partsArr = raw.get('parts');
  if (partsArr !== undefined && partsArr !== null) {
    let parts = partsArr as Array<Object>;
    for (let pi = 0; pi < parts.length; pi++) {
      let partRaw = parts[pi] as Map<string, Object>;
      let pointsArr = partRaw.get('points');
      if (pointsArr !== undefined && pointsArr !== null) {
        let coords: GisCoordinate[] = [];
        let pa = pointsArr as Array<Object>;
        for (let ci = 0; ci < pa.length; ci++) {
          coords.push(parseCoordinate(pa[ci] as Map<string, Object>));
        }
        geom.parts.push(new GisGeometryPart(coords));
      }
    }
  }
  return geom;
}

function parseAttributeValue(raw: Map<string, Object>): GisAttributeValue {
  let attr: GisAttributeValue = new GisAttributeValue('', '', '', 0, false, false);
  attr.name = mapGetString(raw, 'name');
  attr.typeName = mapGetString(raw, 'typeName');
  attr.textValue = mapGetString(raw, 'textValue');
  attr.numberValue = mapGetNumber(raw, 'numberValue');
  attr.boolValue = mapGetBool(raw, 'boolValue');
  attr.isNull = mapGetBool(raw, 'isNull');
  return attr;
}

function parseFeatureSummary(raw: Map<string, Object>): GisFeatureSummary {
  let feat: GisFeatureSummary = new GisFeatureSummary(
    '', new GisGeometryPayload(0, [], new GisEnvelope(0, 0, 0, 0), ''), new GisEnvelope(0, 0, 0, 0), []
  );
  feat.featureId = mapGetString(raw, 'featureId');
  let geomObj = raw.get('geometry');
  if (geomObj !== undefined && geomObj !== null) {
    feat.geometry = parseGeometry(geomObj as Map<string, Object>);
  }
  let envObj = raw.get('envelope');
  if (envObj !== undefined && envObj !== null) {
    feat.envelope = parseEnvelope(envObj as Map<string, Object>);
  }
  let attrsArr = raw.get('attributesPreview');
  if (attrsArr !== undefined && attrsArr !== null) {
    let attrs = attrsArr as Array<Object>;
    for (let ai = 0; ai < attrs.length; ai++) {
      feat.attributesPreview.push(parseAttributeValue(attrs[ai] as Map<string, Object>));
    }
  }
  return feat;
}

function parseGeoProcessResult(raw: Map<string, Object>): GisGeoProcessResult {
  let result = new GisGeoProcessResult(false, 0, '', '', '', 0);
  result.ok = mapGetBool(raw, 'ok');
  result.code = mapGetNumber(raw, 'code');
  result.message = mapGetString(raw, 'message');
  result.outputPath = mapGetString(raw, 'outputPath');
  result.outputLayerName = mapGetString(raw, 'outputLayerName');
  result.featureCount = mapGetNumber(raw, 'featureCount');
  return result;
}

function parseOperationResult(raw: Map<string, Object>): GisOperationResult {
  let result = new GisOperationResult(false, 0, '');
  result.ok = mapGetBool(raw, 'ok');
  result.code = mapGetNumber(raw, 'code');
  result.message = mapGetString(raw, 'message');
  return result;
}

function parseLayerInfo(raw: Map<string, Object>): GisLayerInfo {
  let layerInfo: GisLayerInfo = new GisLayerInfo('', '', 0, 0, new GisEnvelope(0, 0, 0, 0), '', []);

  layerInfo.layerId = mapGetString(raw, 'layerId');
  layerInfo.name = mapGetString(raw, 'name');
  layerInfo.geometryType = mapGetNumber(raw, 'geometryType');
  layerInfo.featureCount = mapGetNumber(raw, 'featureCount');
  layerInfo.crs = mapGetString(raw, 'crs');
  layerInfo.crsDescription = mapGetString(raw, 'crsDescription');
  layerInfo.crsFriendlyName = mapGetString(raw, 'crsFriendlyName');
  layerInfo.projectionAcronym = mapGetString(raw, 'projectionAcronym');
  layerInfo.ellipsoidAcronym = mapGetString(raw, 'ellipsoidAcronym');
  layerInfo.geographicCrsAuthId = mapGetString(raw, 'geographicCrsAuthId');
  layerInfo.crsIsGeographic = mapGetBool(raw, 'crsIsGeographic');
  layerInfo.coordinateUnitName = mapGetString(raw, 'coordinateUnitName');
  layerInfo.coordinateUnitType = mapGetNumber(raw, 'coordinateUnitType');
  layerInfo.legendColor = mapGetString(raw, 'legendColor');
  layerInfo.legendStrokeColor = mapGetString(raw, 'legendStrokeColor');

  let envObj = raw.get('envelope');
  if (envObj !== undefined && envObj !== null) {
    layerInfo.envelope = parseEnvelope(envObj as Map<string, Object>);
  }

  let crsBoundsObj = raw.get('crsBounds');
  if (crsBoundsObj !== undefined && crsBoundsObj !== null) {
    layerInfo.crsBounds = parseEnvelope(crsBoundsObj as Map<string, Object>);
  }

  let fieldsArr = raw.get('fields');
  if (fieldsArr !== undefined && fieldsArr !== null) {
    let fields = fieldsArr as Array<Object>;
    for (let fi = 0; fi < fields.length; fi++) {
      layerInfo.fields.push(parseFieldInfo(fields[fi] as Map<string, Object>));
    }
  }

  return layerInfo;
}

function parseCrsInfo(raw: Map<string, Object>): GisCrsInfo {
  let result: GisCrsInfo = new GisCrsInfo(false, 0, '', '');
  result.ok = mapGetBool(raw, 'ok');
  result.code = mapGetNumber(raw, 'code');
  result.message = mapGetString(raw, 'message');
  result.input = mapGetString(raw, 'input');
  result.isValid = mapGetBool(raw, 'isValid');
  result.authId = mapGetString(raw, 'authId');
  result.description = mapGetString(raw, 'description');
  result.friendlyName = mapGetString(raw, 'friendlyName');
  result.projectionAcronym = mapGetString(raw, 'projectionAcronym');
  result.ellipsoidAcronym = mapGetString(raw, 'ellipsoidAcronym');
  result.geographicCrsAuthId = mapGetString(raw, 'geographicCrsAuthId');
  result.celestialBodyName = mapGetString(raw, 'celestialBodyName');
  result.isGeographic = mapGetBool(raw, 'isGeographic');
  result.hasAxisInverted = mapGetBool(raw, 'hasAxisInverted');
  result.srsId = mapGetNumber(raw, 'srsId');
  result.postgisSrid = mapGetNumber(raw, 'postgisSrid');
  result.mapUnitCode = mapGetNumber(raw, 'mapUnitCode');
  result.unitName = mapGetString(raw, 'unitName');
  result.unitType = mapGetNumber(raw, 'unitType');
  result.proj = mapGetString(raw, 'proj');
  result.wkt = mapGetString(raw, 'wkt');
  let boundsObj = raw.get('bounds');
  if (boundsObj !== undefined && boundsObj !== null) {
    result.bounds = parseEnvelope(boundsObj as Map<string, Object>);
  }
  return result;
}

function parseCoordinateTransformResult(raw: Map<string, Object>): GisCoordinateTransformResult {
  let result: GisCoordinateTransformResult = new GisCoordinateTransformResult(false, 0, '', 0, 0);
  result.ok = mapGetBool(raw, 'ok');
  result.code = mapGetNumber(raw, 'code');
  result.message = mapGetString(raw, 'message');
  result.x = mapGetNumber(raw, 'x');
  result.y = mapGetNumber(raw, 'y');
  result.sourceAuthId = mapGetString(raw, 'sourceAuthId');
  result.targetAuthId = mapGetString(raw, 'targetAuthId');
  return result;
}

function parseEnvelopeTransformResult(raw: Map<string, Object>): GisEnvelopeTransformResult {
  let result: GisEnvelopeTransformResult = new GisEnvelopeTransformResult(false, 0, '', new GisEnvelope(0, 0, 0, 0));
  result.ok = mapGetBool(raw, 'ok');
  result.code = mapGetNumber(raw, 'code');
  result.message = mapGetString(raw, 'message');
  result.sourceAuthId = mapGetString(raw, 'sourceAuthId');
  result.targetAuthId = mapGetString(raw, 'targetAuthId');
  let envObj = raw.get('envelope');
  if (envObj !== undefined && envObj !== null) {
    result.envelope = parseEnvelope(envObj as Map<string, Object>);
  }
  return result;
}

function layerIdToHandle(layerId: string): number {
  let handle: number = 0;
  if (layerId.length > 1) {
    let numStr = layerId.substring(1);
    handle = Number(numStr);
  }
  return handle;
}

function escapeProcessingJsonString(value: string): string {
  let result: string = '';
  for (let i = 0; i < value.length; i++) {
    let c: string = value.charAt(i);
    if (c === '\\') {
      result += '\\\\';
    } else if (c === '"') {
      result += '\\"';
    } else if (c === '\n') {
      result += '\\n';
    } else if (c === '\r') {
      result += '\\r';
    } else if (c === '\t') {
      result += '\\t';
    } else {
      result += c;
    }
  }
  return result;
}

export function bridgeGetProcessingAlgorithms(): string {
  try {
    return getProcessingAlgorithms();
  } catch (e) {
    hilog.error(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeGetProcessingAlgorithms: EXCEPTION');
    return '{"backend":"none","algorithms":[]}';
  }
}

export function bridgeExecuteProcessingAlgorithm(algorithmId: string, inputLayerId: string,
  overlayLayerId: string, numericValue: number, textValue: string, outputPath: string,
  outputLayerName: string): GisGeoProcessResult {
  let inputHandle: number = layerIdToHandle(inputLayerId);
  let overlayHandle: number = layerIdToHandle(overlayLayerId);
  let requestJson: string = '{"algorithmId":"' + escapeProcessingJsonString(algorithmId) +
    '","inputHandle":' + inputHandle.toString() +
    ',"overlayHandle":' + overlayHandle.toString() +
    ',"numericValue":' + numericValue.toString() +
    ',"textValue":"' + escapeProcessingJsonString(textValue) +
    '","outputPath":"' + escapeProcessingJsonString(outputPath) +
    '","outputLayerName":"' + escapeProcessingJsonString(outputLayerName) + '"}';
  try {
    let nativeResult: NativeGeoProcessResult = executeProcessingAlgorithm(requestJson);
    let raw: Object = parseJsonString(nativeResult.resultInfo);
    return parseGeoProcessResult(raw as Map<string, Object>);
  } catch (e) {
    hilog.error(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeExecuteProcessingAlgorithm: EXCEPTION');
    return new GisGeoProcessResult(false, 5, 'Native processing execution failed',
      outputPath, outputLayerName, 0);
  }
}

// ---------------------------------------------------------------------------
// High-level bridge functions
// ---------------------------------------------------------------------------

export function bridgeOpenVectorLayer(filePath: string): GisLayerInfo | undefined {
  try {
    let result: NativeLayerOpenResult = openVectorLayer(filePath);
    hilog.info(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeOpenVectorLayer: errCode=%{public}d, infoLen=%{public}d',
      result.errCode, result.layerInfo.length);
    if (result.errCode !== 0) {
      return undefined;
    }
    let raw: Object = parseJsonString(result.layerInfo);
    let info = raw as Map<string, Object>;
    let layerInfo: GisLayerInfo = parseLayerInfo(info);

    hilog.info(BRIDGE_TAG, BRIDGE_DOMAIN,
      'bridgeOpenVectorLayer: id=%{public}s name=%{public}s geom=%{public}d count=%{public}d env=[%{public}s,%{public}s]-[%{public}s,%{public}s]',
      layerInfo.layerId, layerInfo.name, layerInfo.geometryType, layerInfo.featureCount,
      layerInfo.envelope.minX.toFixed(2), layerInfo.envelope.minY.toFixed(2),
      layerInfo.envelope.maxX.toFixed(2), layerInfo.envelope.maxY.toFixed(2));
    return layerInfo;
  } catch (e) {
    hilog.error(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeOpenVectorLayer: EXCEPTION');
    return undefined;
  }
}

export function bridgeOpenRasterLayer(filePath: string): GisLayerInfo | undefined {
  try {
    let result: NativeLayerOpenResult = openRasterLayer(filePath);
    hilog.info(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeOpenRasterLayer: errCode=%{public}d, infoLen=%{public}d',
      result.errCode, result.layerInfo.length);
    if (result.errCode !== 0) {
      return undefined;
    }
    let raw: Object = parseJsonString(result.layerInfo);
    let info = raw as Map<string, Object>;
    let layerInfo: GisLayerInfo = parseLayerInfo(info);

    hilog.info(BRIDGE_TAG, BRIDGE_DOMAIN,
      'bridgeOpenRasterLayer: id=%{public}s name=%{public}s env=[%{public}s,%{public}s]-[%{public}s,%{public}s]',
      layerInfo.layerId, layerInfo.name,
      layerInfo.envelope.minX.toFixed(2), layerInfo.envelope.minY.toFixed(2),
      layerInfo.envelope.maxX.toFixed(2), layerInfo.envelope.maxY.toFixed(2));
    return layerInfo;
  } catch (e) {
    hilog.error(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeOpenRasterLayer: EXCEPTION');
    return undefined;
  }
}

export function bridgeGetLayerInfo(layerId: string): GisLayerInfo | undefined {
  let handle: number = layerIdToHandle(layerId);
  if (handle <= 0) {
    return undefined;
  }
  try {
    let result: NativeLayerInfoResult = getLayerInfo(handle);
    hilog.info(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeGetLayerInfo: errCode=%{public}d, infoLen=%{public}d',
      result.errCode, result.layerInfo.length);
    if (result.errCode !== 0) {
      return undefined;
    }
    let raw: Object = parseJsonString(result.layerInfo);
    return parseLayerInfo(raw as Map<string, Object>);
  } catch (e) {
    hilog.error(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeGetLayerInfo: EXCEPTION');
    return undefined;
  }
}

export function bridgeDescribeCoordinateReferenceSystem(definition: string): GisCrsInfo {
  try {
    let result: NativeGeoProcessResult = describeCoordinateReferenceSystem(definition);
    let raw: Object = parseJsonString(result.resultInfo);
    return parseCrsInfo(raw as Map<string, Object>);
  } catch (e) {
    hilog.error(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeDescribeCoordinateReferenceSystem: EXCEPTION');
    return new GisCrsInfo(false, 5, 'Native CRS describe failed', definition);
  }
}

export function bridgeTransformCoordinate(sourceDefinition: string, targetDefinition: string, x: number,
  y: number): GisCoordinateTransformResult {
  try {
    let result: NativeGeoProcessResult = transformCoordinate(sourceDefinition, targetDefinition, x, y);
    let raw: Object = parseJsonString(result.resultInfo);
    return parseCoordinateTransformResult(raw as Map<string, Object>);
  } catch (e) {
    hilog.error(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeTransformCoordinate: EXCEPTION');
    return new GisCoordinateTransformResult(false, 5, 'Native coordinate transform failed', 0, 0);
  }
}

export function bridgeTransformEnvelope(sourceDefinition: string, targetDefinition: string, envelope: GisEnvelope):
  GisEnvelopeTransformResult {
  try {
    let result: NativeGeoProcessResult = transformEnvelope(sourceDefinition, targetDefinition, envelope.minX,
      envelope.minY, envelope.maxX, envelope.maxY);
    let raw: Object = parseJsonString(result.resultInfo);
    return parseEnvelopeTransformResult(raw as Map<string, Object>);
  } catch (e) {
    hilog.error(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeTransformEnvelope: EXCEPTION');
    return new GisEnvelopeTransformResult(false, 5, 'Native envelope transform failed', new GisEnvelope(0, 0, 0, 0));
  }
}

export function bridgeQueryFeatures(layerId: string, minX: number, minY: number, maxX: number, maxY: number,
  limit: number): GisFeaturePage | undefined {
  let handle: number = layerIdToHandle(layerId);
  if (handle <= 0) {
    return undefined;
  }
  try {
    let result: NativeFeaturePageResult = queryFeatures(handle, minX, minY, maxX, maxY, limit);
    hilog.info(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeQueryFeatures: errCode=%{public}d, pageLen=%{public}d',
      result.errCode, result.featurePage.length);
    if (result.errCode !== 0) {
      return undefined;
    }
    let raw: Object = parseJsonString(result.featurePage);
    let page = raw as Map<string, Object>;
    let featurePage: GisFeaturePage = new GisFeaturePage(layerId, [], false);
    featurePage.hasMore = mapGetBool(page, 'hasMore');
    let featuresArr = page.get('features');
    if (featuresArr !== undefined && featuresArr !== null) {
      let features = featuresArr as Array<Object>;
      for (let fi = 0; fi < features.length; fi++) {
        featurePage.features.push(parseFeatureSummary(features[fi] as Map<string, Object>));
      }
    }
    hilog.info(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeQueryFeatures: loaded %{public}d features',
      featurePage.features.length);
    return featurePage;
  } catch (e) {
    hilog.error(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeQueryFeatures: EXCEPTION');
    return undefined;
  }
}

export function bridgeGetFeature(layerId: string, fid: number): GisFeatureSummary | undefined {
  let handle: number = layerIdToHandle(layerId);
  if (handle <= 0) {
    return undefined;
  }
  try {
    let result: NativeFeatureResult = getFeature(handle, fid);
    if (result.errCode !== 0) {
      return undefined;
    }
    let raw: Object = parseJsonString(result.feature);
    return parseFeatureSummary(raw as Map<string, Object>);
  } catch (e) {
    hilog.error(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeGetFeature: EXCEPTION');
    return undefined;
  }
}

export function bridgeCloseLayer(layerId: string): GisOperationResult {
  let handle: number = layerIdToHandle(layerId);
  if (handle <= 0) {
    return new GisOperationResult(false, 3, 'Invalid layer handle');
  }
  try {
    let errCode: number = closeLayer(handle);
    return new GisOperationResult(errCode === 0, errCode, errCode === 0 ? 'OK' : 'Close failed');
  } catch (e) {
    return new GisOperationResult(false, 5, 'Native call failed');
  }
}

export function bridgeBufferLayer(layerId: string, distance: number, outputPath: string,
  outputLayerName: string): GisGeoProcessResult {
  let handle: number = layerIdToHandle(layerId);
  if (handle <= 0) {
    return new GisGeoProcessResult(false, 3, 'Invalid layer handle', outputPath, outputLayerName, 0);
  }
  try {
    let result: NativeGeoProcessResult = bufferLayer(handle, distance, outputPath, outputLayerName);
    let raw: Object = parseJsonString(result.resultInfo);
    return parseGeoProcessResult(raw as Map<string, Object>);
  } catch (e) {
    hilog.error(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeBufferLayer: EXCEPTION');
    return new GisGeoProcessResult(false, 5, 'Native buffer failed', outputPath, outputLayerName, 0);
  }
}

export function bridgeSimplifyLayer(layerId: string, tolerance: number, outputPath: string,
  outputLayerName: string): GisGeoProcessResult {
  let handle: number = layerIdToHandle(layerId);
  if (handle <= 0) {
    return new GisGeoProcessResult(false, 3, 'Invalid layer handle', outputPath, outputLayerName, 0);
  }
  try {
    let result: NativeGeoProcessResult = simplifyLayer(handle, tolerance, outputPath, outputLayerName);
    let raw: Object = parseJsonString(result.resultInfo);
    return parseGeoProcessResult(raw as Map<string, Object>);
  } catch (e) {
    hilog.error(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeSimplifyLayer: EXCEPTION');
    return new GisGeoProcessResult(false, 5, 'Native simplify failed', outputPath, outputLayerName, 0);
  }
}

export function bridgeDissolveLayer(layerId: string, outputPath: string,
  outputLayerName: string): GisGeoProcessResult {
  let handle: number = layerIdToHandle(layerId);
  if (handle <= 0) {
    return new GisGeoProcessResult(false, 3, 'Invalid layer handle', outputPath, outputLayerName, 0);
  }
  try {
    let result: NativeGeoProcessResult = dissolveLayer(handle, outputPath, outputLayerName);
    let raw: Object = parseJsonString(result.resultInfo);
    return parseGeoProcessResult(raw as Map<string, Object>);
  } catch (e) {
    hilog.error(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeDissolveLayer: EXCEPTION');
    return new GisGeoProcessResult(false, 5, 'Native dissolve failed', outputPath, outputLayerName, 0);
  }
}

export function bridgeCentroidLayer(layerId: string, outputPath: string,
  outputLayerName: string): GisGeoProcessResult {
  let handle: number = layerIdToHandle(layerId);
  if (handle <= 0) {
    return new GisGeoProcessResult(false, 3, 'Invalid layer handle', outputPath, outputLayerName, 0);
  }
  try {
    let result: NativeGeoProcessResult = centroidLayer(handle, outputPath, outputLayerName);
    let raw: Object = parseJsonString(result.resultInfo);
    return parseGeoProcessResult(raw as Map<string, Object>);
  } catch (e) {
    hilog.error(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeCentroidLayer: EXCEPTION');
    return new GisGeoProcessResult(false, 5, 'Native centroid failed', outputPath, outputLayerName, 0);
  }
}

export function bridgeRepairLayer(layerId: string, outputPath: string,
  outputLayerName: string): GisGeoProcessResult {
  let handle: number = layerIdToHandle(layerId);
  if (handle <= 0) {
    return new GisGeoProcessResult(false, 3, 'Invalid layer handle', outputPath, outputLayerName, 0);
  }
  try {
    let result: NativeGeoProcessResult = repairLayer(handle, outputPath, outputLayerName);
    let raw: Object = parseJsonString(result.resultInfo);
    return parseGeoProcessResult(raw as Map<string, Object>);
  } catch (e) {
    hilog.error(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeRepairLayer: EXCEPTION');
    return new GisGeoProcessResult(false, 5, 'Native repair failed', outputPath, outputLayerName, 0);
  }
}

export function bridgeClipLayer(inputLayerId: string, clipLayerId: string, outputPath: string,
  outputLayerName: string): GisGeoProcessResult {
  let inputHandle: number = layerIdToHandle(inputLayerId);
  let clipHandle: number = layerIdToHandle(clipLayerId);
  if (inputHandle <= 0 || clipHandle <= 0) {
    return new GisGeoProcessResult(false, 3, 'Invalid layer handle', outputPath, outputLayerName, 0);
  }
  try {
    let result: NativeGeoProcessResult = clipLayer(inputHandle, clipHandle, outputPath, outputLayerName);
    let raw: Object = parseJsonString(result.resultInfo);
    return parseGeoProcessResult(raw as Map<string, Object>);
  } catch (e) {
    hilog.error(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeClipLayer: EXCEPTION');
    return new GisGeoProcessResult(false, 5, 'Native clip failed', outputPath, outputLayerName, 0);
  }
}

export function bridgeExportLayer(layerId: string, outputPath: string, outputLayerName: string): GisGeoProcessResult {
  let handle: number = layerIdToHandle(layerId);
  if (handle <= 0) {
    return new GisGeoProcessResult(false, 3, 'Invalid layer handle', outputPath, outputLayerName, 0);
  }
  try {
    let result: NativeGeoProcessResult = exportLayer(handle, outputPath, outputLayerName);
    let raw: Object = parseJsonString(result.resultInfo);
    return parseGeoProcessResult(raw as Map<string, Object>);
  } catch (e) {
    hilog.error(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeExportLayer: EXCEPTION');
    return new GisGeoProcessResult(false, 5, 'Native export failed', outputPath, outputLayerName, 0);
  }
}

export function bridgeDefineLayerProjection(layerId: string, targetDefinition: string, outputPath: string,
  outputLayerName: string): GisGeoProcessResult {
  let handle: number = layerIdToHandle(layerId);
  if (handle <= 0) {
    return new GisGeoProcessResult(false, 3, 'Invalid layer handle', outputPath, outputLayerName, 0);
  }
  try {
    let result: NativeGeoProcessResult = defineLayerProjection(handle, targetDefinition, outputPath, outputLayerName);
    let raw: Object = parseJsonString(result.resultInfo);
    return parseGeoProcessResult(raw as Map<string, Object>);
  } catch (e) {
    hilog.error(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeDefineLayerProjection: EXCEPTION');
    return new GisGeoProcessResult(false, 5, 'Native define projection failed', outputPath, outputLayerName, 0);
  }
}

export function bridgeProjectLayer(layerId: string, targetDefinition: string, outputPath: string,
  outputLayerName: string): GisGeoProcessResult {
  let handle: number = layerIdToHandle(layerId);
  if (handle <= 0) {
    return new GisGeoProcessResult(false, 3, 'Invalid layer handle', outputPath, outputLayerName, 0);
  }
  try {
    let result: NativeGeoProcessResult = projectLayer(handle, targetDefinition, outputPath, outputLayerName);
    let raw: Object = parseJsonString(result.resultInfo);
    return parseGeoProcessResult(raw as Map<string, Object>);
  } catch (e) {
    hilog.error(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeProjectLayer: EXCEPTION');
    return new GisGeoProcessResult(false, 5, 'Native project failed', outputPath, outputLayerName, 0);
  }
}

export function bridgeApplyVectorStyle(layerId: string, rendererMode: number, rendererField: string,
  colorRamp: number, linePattern: number, fillPattern: number, pointColor: string, lineColor: string,
  fillColor: string, strokeColor: string, lineWidth: number, pointRadius: number, opacity: number,
  symbolName: string): GisOperationResult {
  let handle: number = layerIdToHandle(layerId);
  if (handle <= 0) {
    return new GisOperationResult(false, 3, 'Invalid layer handle');
  }
  try {
    return bridgeEditResult(applyVectorStyle(handle, rendererMode, rendererField, colorRamp, linePattern,
      fillPattern, pointColor, lineColor, fillColor, strokeColor, lineWidth, pointRadius, opacity, symbolName));
  } catch (e) {
    hilog.error(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeApplyVectorStyle: EXCEPTION');
    return new GisOperationResult(false, 5, 'Native vector style failed');
  }
}

export function bridgeApplyVectorLabeling(layerId: string, enabled: boolean, labelField: string,
  labelSize: number, labelColor: string, halo: boolean, avoidance: boolean, minScale: number,
  maxScale: number): GisOperationResult {
  let handle: number = layerIdToHandle(layerId);
  if (handle <= 0) {
    return new GisOperationResult(false, 3, 'Invalid layer handle');
  }
  try {
    return bridgeEditResult(applyVectorLabeling(handle, enabled, labelField, labelSize, labelColor, halo,
      avoidance, minScale, maxScale));
  } catch (e) {
    hilog.error(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeApplyVectorLabeling: EXCEPTION');
    return new GisOperationResult(false, 5, 'Native vector labeling failed');
  }
}

export function bridgeConfigureRasterDisplay(layerId: string, bandMode: number, stretchMode: number,
  colorRamp: number, opacity: number, noData: string, transparentColor: string,
  hillshade: boolean): GisOperationResult {
  let handle: number = layerIdToHandle(layerId);
  if (handle <= 0) {
    return new GisOperationResult(false, 3, 'Invalid layer handle');
  }
  try {
    return bridgeEditResult(configureRasterDisplay(handle, bandMode, stretchMode, colorRamp, opacity, noData,
      transparentColor, hillshade));
  } catch (e) {
    hilog.error(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeConfigureRasterDisplay: EXCEPTION');
    return new GisOperationResult(false, 5, 'Native raster display failed');
  }
}

export function bridgeExportMapLayout(title: string, outputPath: string, format: string, showLegend: boolean,
  showScaleBar: boolean, showNorthArrow: boolean, showGrid: boolean, width: number,
  height: number, legendTitle: string, scaleText: string, footerText: string, basemapMode: number,
  basemapLabel: string, visibleLayerHandles: string): GisGeoProcessResult {
  try {
    let result: NativeGeoProcessResult = exportMapLayout(title, outputPath, format, showLegend, showScaleBar,
      showNorthArrow, showGrid, width, height, legendTitle, scaleText, footerText, basemapMode, basemapLabel,
      visibleLayerHandles);
    let raw: Object = parseJsonString(result.resultInfo);
    return parseGeoProcessResult(raw as Map<string, Object>);
  } catch (e) {
    hilog.error(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeExportMapLayout: EXCEPTION');
    return new GisGeoProcessResult(false, 5, 'Native map layout export failed', outputPath, title, 0);
  }
}

function coordinatesToText(points: GisCoordinate[]): string {
  let text = '';
  for (let i = 0; i < points.length; i++) {
    if (i > 0) {
      text += ';';
    }
    text += points[i].x.toString() + ',' + points[i].y.toString();
  }
  return text;
}

function bridgeEditResult(result: NativeGeoProcessResult): GisOperationResult {
  let raw: Object = parseJsonString(result.resultInfo);
  return parseOperationResult(raw as Map<string, Object>);
}

export function bridgeAddFeature(layerId: string, geometryType: number, points: GisCoordinate[]): GisOperationResult {
  let handle: number = layerIdToHandle(layerId);
  if (handle <= 0) {
    return new GisOperationResult(false, 3, 'Invalid layer handle');
  }
  try {
    return bridgeEditResult(addFeature(handle, geometryType, coordinatesToText(points)));
  } catch (e) {
    hilog.error(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeAddFeature: EXCEPTION');
    return new GisOperationResult(false, 5, 'Native add feature failed');
  }
}

export function bridgeDeleteFeature(layerId: string, featureId: string): GisOperationResult {
  let handle: number = layerIdToHandle(layerId);
  if (handle <= 0) {
    return new GisOperationResult(false, 3, 'Invalid layer handle');
  }
  try {
    return bridgeEditResult(deleteFeature(handle, Number(featureId)));
  } catch (e) {
    hilog.error(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeDeleteFeature: EXCEPTION');
    return new GisOperationResult(false, 5, 'Native delete feature failed');
  }
}

export function bridgeMoveFeatureNode(layerId: string, featureId: string, partIndex: number, pointIndex: number,
  x: number, y: number): GisOperationResult {
  let handle: number = layerIdToHandle(layerId);
  if (handle <= 0) {
    return new GisOperationResult(false, 3, 'Invalid layer handle');
  }
  try {
    return bridgeEditResult(moveFeatureNode(handle, Number(featureId), partIndex, pointIndex, x, y));
  } catch (e) {
    hilog.error(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeMoveFeatureNode: EXCEPTION');
    return new GisOperationResult(false, 5, 'Native move node failed');
  }
}

export function bridgeDeleteFeatureNode(layerId: string, featureId: string, partIndex: number,
  pointIndex: number): GisOperationResult {
  let handle: number = layerIdToHandle(layerId);
  if (handle <= 0) {
    return new GisOperationResult(false, 3, 'Invalid layer handle');
  }
  try {
    return bridgeEditResult(deleteFeatureNode(handle, Number(featureId), partIndex, pointIndex));
  } catch (e) {
    hilog.error(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeDeleteFeatureNode: EXCEPTION');
    return new GisOperationResult(false, 5, 'Native delete node failed');
  }
}

export function bridgeCopyFeature(layerId: string, featureId: string): GisOperationResult {
  let handle: number = layerIdToHandle(layerId);
  if (handle <= 0) {
    return new GisOperationResult(false, 3, 'Invalid layer handle');
  }
  try {
    return bridgeEditResult(copyFeature(handle, Number(featureId)));
  } catch (e) {
    hilog.error(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeCopyFeature: EXCEPTION');
    return new GisOperationResult(false, 5, 'Native copy feature failed');
  }
}

export function bridgeSplitFeature(layerId: string, featureId: string, points: GisCoordinate[]): GisOperationResult {
  let handle: number = layerIdToHandle(layerId);
  if (handle <= 0) {
    return new GisOperationResult(false, 3, 'Invalid layer handle');
  }
  try {
    return bridgeEditResult(splitFeature(handle, Number(featureId), coordinatesToText(points)));
  } catch (e) {
    hilog.error(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeSplitFeature: EXCEPTION');
    return new GisOperationResult(false, 5, 'Native split feature failed');
  }
}

export function bridgeMergeFeatures(layerId: string, featureIdList: string): GisOperationResult {
  let handle: number = layerIdToHandle(layerId);
  if (handle <= 0) {
    return new GisOperationResult(false, 3, 'Invalid layer handle');
  }
  try {
    return bridgeEditResult(mergeFeatures(handle, featureIdList));
  } catch (e) {
    hilog.error(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeMergeFeatures: EXCEPTION');
    return new GisOperationResult(false, 5, 'Native merge features failed');
  }
}

export function bridgeSnapLayer(layerId: string, targetLayerId: string, tolerance: number): GisOperationResult {
  let handle: number = layerIdToHandle(layerId);
  let targetHandle: number = layerIdToHandle(targetLayerId);
  if (handle <= 0) {
    return new GisOperationResult(false, 3, 'Invalid layer handle');
  }
  try {
    return bridgeEditResult(snapLayer(handle, targetHandle, tolerance));
  } catch (e) {
    hilog.error(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeSnapLayer: EXCEPTION');
    return new GisOperationResult(false, 5, 'Native snap layer failed');
  }
}

export function bridgeUpdateFeatureAttribute(layerId: string, featureId: string, fieldName: string,
  value: string): GisOperationResult {
  let handle: number = layerIdToHandle(layerId);
  if (handle <= 0) {
    return new GisOperationResult(false, 3, 'Invalid layer handle');
  }
  try {
    return bridgeEditResult(updateFeatureAttribute(handle, Number(featureId), fieldName, value));
  } catch (e) {
    hilog.error(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeUpdateFeatureAttribute: EXCEPTION');
    return new GisOperationResult(false, 5, 'Native update attribute failed');
  }
}

export function bridgeBatchAssignAttribute(layerId: string, fieldName: string, filterText: string,
  value: string): GisOperationResult {
  let handle: number = layerIdToHandle(layerId);
  if (handle <= 0) {
    return new GisOperationResult(false, 3, 'Invalid layer handle');
  }
  try {
    return bridgeEditResult(batchAssignAttribute(handle, fieldName, filterText, value));
  } catch (e) {
    hilog.error(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeBatchAssignAttribute: EXCEPTION');
    return new GisOperationResult(false, 5, 'Native batch assign failed');
  }
}

export function bridgeAddLayerField(layerId: string, fieldName: string, typeName: string): GisOperationResult {
  let handle: number = layerIdToHandle(layerId);
  if (handle <= 0) {
    return new GisOperationResult(false, 3, 'Invalid layer handle');
  }
  try {
    return bridgeEditResult(addLayerField(handle, fieldName, typeName));
  } catch (e) {
    hilog.error(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeAddLayerField: EXCEPTION');
    return new GisOperationResult(false, 5, 'Native add field failed');
  }
}

export function bridgeDeleteLayerField(layerId: string, fieldName: string): GisOperationResult {
  let handle: number = layerIdToHandle(layerId);
  if (handle <= 0) {
    return new GisOperationResult(false, 3, 'Invalid layer handle');
  }
  try {
    return bridgeEditResult(deleteLayerField(handle, fieldName));
  } catch (e) {
    hilog.error(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeDeleteLayerField: EXCEPTION');
    return new GisOperationResult(false, 5, 'Native delete field failed');
  }
}

export function bridgeCalculateField(layerId: string, fieldName: string, calculatorMode: number,
  constantValue: string): GisOperationResult {
  let handle: number = layerIdToHandle(layerId);
  if (handle <= 0) {
    return new GisOperationResult(false, 3, 'Invalid layer handle');
  }
  try {
    return bridgeEditResult(calculateField(handle, fieldName, calculatorMode, constantValue));
  } catch (e) {
    hilog.error(BRIDGE_TAG, BRIDGE_DOMAIN, 'bridgeCalculateField: EXCEPTION');
    return new GisOperationResult(false, 5, 'Native calculate field failed');
  }
}
