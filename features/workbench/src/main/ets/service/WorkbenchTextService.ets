import util from '@ohos.util';
import { ClipboardCoordinateCandidate, RecentProjectRecord } from '../model/WorkbenchModels';

export class WorkbenchTextService {
  static fileExtension(fileName: string): string {
    let dotIndex: number = fileName.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex >= fileName.length - 1) {
      return '';
    }
    return fileName.substring(dotIndex + 1).toLowerCase();
  }

  static isVectorOrTableFormat(extension: string): boolean {
    return extension === 'shp' || extension === 'geojson' || extension === 'json' || extension === 'gpkg' ||
      extension === 'kml' || extension === 'kmz' || extension === 'csv' || extension === 'xlsx' ||
      extension === 'xls' || extension === 'fgb';
  }

  static isRasterOrTileFormat(extension: string): boolean {
    return extension === 'tif' || extension === 'tiff' || extension === 'mbtiles';
  }

  static isArchiveFormat(extension: string): boolean {
    return extension === 'zip';
  }

  static fileBaseName(fileName: string): string {
    let dotIndex: number = fileName.lastIndexOf('.');
    if (dotIndex <= 0) {
      return fileName;
    }
    return fileName.substring(0, dotIndex);
  }

  private static hexDigitValue(character: string): number {
    if (character >= '0' && character <= '9') {
      return character.charCodeAt(0) - '0'.charCodeAt(0);
    }
    if (character >= 'A' && character <= 'F') {
      return character.charCodeAt(0) - 'A'.charCodeAt(0) + 10;
    }
    if (character >= 'a' && character <= 'f') {
      return character.charCodeAt(0) - 'a'.charCodeAt(0) + 10;
    }
    return -1;
  }

  private static encodeByteFallback(bytes: number[]): string {
    let result: string = '';
    for (let i: number = 0; i < bytes.length; i++) {
      let hex: string = bytes[i].toString(16).toUpperCase();
      if (hex.length < 2) {
        result += '%0' + hex;
      } else {
        result += '%' + hex;
      }
    }
    return result;
  }

  private static decodeUtf8Bytes(bytes: number[]): string {
    if (bytes.length === 0) {
      return '';
    }
    try {
      let data: Uint8Array = new Uint8Array(bytes.length);
      for (let i: number = 0; i < bytes.length; i++) {
        data[i] = bytes[i];
      }
      let decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
      return decoder.decodeToString(data);
    } catch (error) {
      return WorkbenchTextService.encodeByteFallback(bytes);
    }
  }

  static decodePercentEncodedText(text: string): string {
    let result: string = '';
    let bytes: number[] = [];
    let index: number = 0;
    while (index < text.length) {
      let character: string = text.charAt(index);
      if (character === '%' && index + 2 < text.length) {
        let high: number = WorkbenchTextService.hexDigitValue(text.charAt(index + 1));
        let low: number = WorkbenchTextService.hexDigitValue(text.charAt(index + 2));
        if (high >= 0 && low >= 0) {
          bytes.push(high * 16 + low);
          index += 3;
          continue;
        }
      }
      if (bytes.length > 0) {
        result += WorkbenchTextService.decodeUtf8Bytes(bytes);
        bytes = [];
      }
      result += character;
      index++;
    }
    if (bytes.length > 0) {
      result += WorkbenchTextService.decodeUtf8Bytes(bytes);
    }
    return result;
  }

  static displayFileName(fileName: string): string {
    let decoded: string = WorkbenchTextService.decodePercentEncodedText(fileName);
    if (decoded.length > 0) {
      return decoded;
    }
    return fileName;
  }

  static safePathSegment(text: string): string {
    let result: string = '';
    for (let i: number = 0; i < text.length; i++) {
      let character: string = text.charAt(i);
      if ((character >= '0' && character <= '9') || (character >= 'A' && character <= 'Z') ||
        (character >= 'a' && character <= 'z') || character === '-' || character === '_') {
        result += character;
      } else {
        result += '_';
      }
    }
    return result.length === 0 ? 'dataset' : result;
  }

  private static isNumberCharacter(character: string): boolean {
    if (character.length === 0) {
      return false;
    }
    let code: number = character.charCodeAt(0);
    if (code >= 48 && code <= 57) {
      return true;
    }
    return character === '.' || character === '-' || character === '+';
  }

  private static trailingNumberText(text: string): string {
    let result: string = '';
    for (let i: number = text.length - 1; i >= 0; i--) {
      let character: string = text.charAt(i);
      if (result.length === 0 && (character === ' ' || character === '\t')) {
        continue;
      }
      if (WorkbenchTextService.isNumberCharacter(character)) {
        result = character + result;
      } else if (result.length > 0) {
        break;
      }
    }
    return result;
  }

  private static leadingNumberText(text: string): string {
    let result: string = '';
    for (let i: number = 0; i < text.length; i++) {
      let character: string = text.charAt(i);
      if (result.length === 0 && (character === ' ' || character === '\t')) {
        continue;
      }
      if (WorkbenchTextService.isNumberCharacter(character)) {
        result += character;
      } else if (result.length > 0) {
        break;
      }
    }
    return result;
  }

  static parseClipboardCoordinate(text: string): ClipboardCoordinateCandidate {
    let lines: string[] = text.split('\n');
    for (let i: number = 0; i < lines.length; i++) {
      let line: string = lines[i];
      let commaIndex: number = line.indexOf(',');
      if (commaIndex < 0) {
        commaIndex = line.indexOf('，');
      }
      if (commaIndex < 0) {
        continue;
      }
      let xText: string = WorkbenchTextService.trailingNumberText(line.substring(0, commaIndex));
      let yText: string = WorkbenchTextService.leadingNumberText(line.substring(commaIndex + 1));
      if (xText.length === 0 || yText.length === 0) {
        continue;
      }
      let xValue: number = Number(xText);
      let yValue: number = Number(yText);
      if (xValue === xValue && yValue === yValue) {
        return new ClipboardCoordinateCandidate(true, xValue, yValue);
      }
    }
    return new ClipboardCoordinateCandidate(false, 0, 0);
  }

  static normalizedText(value: string, fallback: string): string {
    let trimmed: string = value.trim();
    return trimmed.length > 0 ? trimmed : fallback;
  }

  private static isInvalidFileCharacter(value: string): boolean {
    return value === '/' || value === '\\' || value === ':' || value === '*' || value === '?' ||
      value === '"' || value === '<' || value === '>' || value === '|';
  }

  static safeProjectFileBaseName(source: string): string {
    let result: string = '';
    for (let i: number = 0; i < source.length; i++) {
      let character: string = source.charAt(i);
      if (WorkbenchTextService.isInvalidFileCharacter(character) || character === '\r' || character === '\n' ||
        character === '\t') {
        result += '_';
      } else {
        result += character;
      }
    }
    result = result.trim();
    return result.length === 0 ? 'GeoNestProject' : result;
  }

  static defaultProjectFileName(title: string): string {
    let baseName: string = WorkbenchTextService.safeProjectFileBaseName(title);
    return baseName.toLowerCase().endsWith('.gnproj') ? baseName : baseName + '.gnproj';
  }

  static isQgisProjectExtension(extension: string): boolean {
    return extension === 'qgs' || extension === 'qgz';
  }

  static extractFileName(uri: string, fallback: string): string {
    let fileName: string = uri;
    let lastSlash: number = uri.lastIndexOf('/');
    if (lastSlash >= 0 && lastSlash < uri.length - 1) {
      fileName = uri.substring(lastSlash + 1);
    }
    let lastBackSlash: number = fileName.lastIndexOf('\\');
    if (lastBackSlash >= 0 && lastBackSlash < fileName.length - 1) {
      fileName = fileName.substring(lastBackSlash + 1);
    }
    return fileName.length === 0 ? fallback : fileName;
  }

  static cleanProjectLine(value: string): string {
    return value.endsWith('\r') ? value.substring(0, value.length - 1) : value;
  }

  static projectValue(lines: string[], key: string): string {
    let prefix: string = key + '=';
    for (let i: number = 0; i < lines.length; i++) {
      let line: string = WorkbenchTextService.cleanProjectLine(lines[i]);
      if (line.startsWith(prefix)) {
        return line.substring(prefix.length);
      }
    }
    return '';
  }

  static projectNumberValue(lines: string[], key: string, fallback: number): number {
    let text: string = WorkbenchTextService.projectValue(lines, key);
    if (text.length === 0) {
      return fallback;
    }
    let value: number = Number(text);
    return value === value ? value : fallback;
  }

  static projectBooleanValue(lines: string[], key: string, fallback: boolean): boolean {
    let text: string = WorkbenchTextService.projectValue(lines, key);
    if (text === 'true') {
      return true;
    }
    if (text === 'false') {
      return false;
    }
    return fallback;
  }

  static sanitizeLineValue(value: string): string {
    let result: string = '';
    for (let i: number = 0; i < value.length; i++) {
      let character: string = value.charAt(i);
      result += character === '\r' || character === '\n' || character === '\t' ? ' ' : character;
    }
    return result;
  }

  static parentDirectory(path: string): string {
    let slashIndex: number = path.lastIndexOf('/');
    return slashIndex <= 0 ? '' : path.substring(0, slashIndex);
  }

  static fileStem(fileName: string): string {
    let dotIndex: number = fileName.lastIndexOf('.');
    return dotIndex <= 0 ? fileName : fileName.substring(0, dotIndex);
  }

  static parseRecentProjectLine(line: string): RecentProjectRecord | undefined {
    let cleanLine: string = WorkbenchTextService.cleanProjectLine(line);
    if (cleanLine.length === 0) {
      return undefined;
    }
    let parts: string[] = cleanLine.split('\t');
    if (parts.length === 0 || parts[0].length === 0) {
      return undefined;
    }
    let name: string = parts.length > 1 ? parts[1] : '';
    let owner: string = parts.length > 2 ? parts[2] : '';
    let crs: string = parts.length > 3 ? parts[3] : '';
    let workspaceName: string = parts.length > 4 ? parts[4] : '';
    return new RecentProjectRecord(parts[0], name, owner, crs, workspaceName);
  }

  static normalizedSearchText(value: string): string {
    return value.trim().toLowerCase();
  }

  private static isSearchSeparator(character: string): boolean {
    let code: number = character.charCodeAt(0);
    if (code <= 32) {
      return true;
    }
    return character === '-' || character === '_' || character === '/' || character === '\\' ||
      character === '.' || character === '·' || character === ':' || character === ';' || character === ',' ||
      character === '，' || character === '。' || character === '(' || character === ')' || character === '（' ||
      character === '）' || character === '[' || character === ']' || character === '【' || character === '】';
  }

  static compactSearchText(value: string): string {
    let lower: string = value.toLowerCase();
    let result: string = '';
    for (let i: number = 0; i < lower.length; i++) {
      let character: string = lower.charAt(i);
      if (!WorkbenchTextService.isSearchSeparator(character)) {
        result += character;
      }
    }
    return result;
  }

  private static pinyinInitialForChar(character: string): string {
    if ('啊阿按案奥'.indexOf(character) >= 0) return 'a';
    if ('把八巴包报保备北本比边编便表标别并部布不版半办'.indexOf(character) >= 0) return 'b';
    if ('才采裁参层查差常场成程城重出初创窗存错测词村'.indexOf(character) >= 0) return 'c';
    if ('大单道到导地第点电定动度端对多打带代登低底叠'.indexOf(character) >= 0) return 'd';
    if ('二'.indexOf(character) >= 0) return 'e';
    if ('发法反范方放分服符复父否封峰'.indexOf(character) >= 0) return 'f';
    if ('该改概干高个格给工公共构关管广规归国果过'.indexOf(character) >= 0) return 'g';
    if ('海汉航合河核何和缓环换绘化话画'.indexOf(character) >= 0) return 'h';
    if ('基机积级籍几计记集加夹建键检简剪间件交角接节结解界近进经径据矩距局具卷'.indexOf(character) >= 0) return 'j';
    if ('开看可空控库快框块'.indexOf(character) >= 0) return 'k';
    if ('拉览栏类理立例连量列邻流路录率轮廓'.indexOf(character) >= 0) return 'l';
    if ('码面名明模默目'.indexOf(character) >= 0) return 'm';
    if ('内南能逆年拟农'.indexOf(character) >= 0) return 'n';
    if ('欧'.indexOf(character) >= 0) return 'o';
    if ('排配批片平坡破普'.indexOf(character) >= 0) return 'p';
    if ('其期齐起器前切清区取全权群缺确'.indexOf(character) >= 0) return 'q';
    if ('然热人任入软融'.indexOf(character) >= 0) return 'r';
    if ('三色删山上少设省生矢始式示市收首数属双水顺司丝索搜速算缩森'.indexOf(character) >= 0) return 's';
    if ('台态泰套体填条调同统投图土拖凸'.indexOf(character) >= 0) return 't';
    if ('外完网微为位未文问务误无五物'.indexOf(character) >= 0) return 'w';
    if ('西析息系细下显线县限项像向小效写新信形型性修选旋'.indexOf(character) >= 0) return 'x';
    if ('压验言研延演样业页一仪已以影应用由右域元原源约云运印'.indexOf(character) >= 0) return 'y';
    if ('在栅站张找照折整正支知质置中终轴主注转准状庄装坐作最左'.indexOf(character) >= 0) return 'z';
    return '';
  }

  private static pinyinInitialsForText(value: string): string {
    let result: string = '';
    for (let i: number = 0; i < value.length; i++) {
      result += WorkbenchTextService.pinyinInitialForChar(value.charAt(i));
    }
    return result;
  }

  private static orderedSubsequenceMatches(keyword: string, sourceText: string): boolean {
    if (keyword.length === 0) {
      return true;
    }
    let keywordIndex: number = 0;
    for (let i: number = 0; i < sourceText.length; i++) {
      if (sourceText.charAt(i) === keyword.charAt(keywordIndex)) {
        keywordIndex++;
        if (keywordIndex >= keyword.length) {
          return true;
        }
      }
    }
    return false;
  }

  static searchMatches(keyword: string, sourceText: string): boolean {
    let normalizedKeyword: string = WorkbenchTextService.normalizedSearchText(keyword);
    if (normalizedKeyword.length === 0) {
      return true;
    }
    let keywordCompact: string = WorkbenchTextService.compactSearchText(normalizedKeyword);
    let sourceLower: string = sourceText.toLowerCase();
    let sourceCompact: string = WorkbenchTextService.compactSearchText(sourceLower);
    let sourceInitials: string = WorkbenchTextService.pinyinInitialsForText(sourceLower);
    let expandedSource: string = sourceLower + ' ' + sourceCompact + ' ' + sourceInitials;
    if (expandedSource.indexOf(normalizedKeyword) >= 0) {
      return true;
    }
    if (keywordCompact.length > 0 && expandedSource.indexOf(keywordCompact) >= 0) {
      return true;
    }
    if (keywordCompact.length >= 2) {
      return WorkbenchTextService.orderedSubsequenceMatches(keywordCompact,
        WorkbenchTextService.compactSearchText(expandedSource));
    }
    return false;
  }
}
