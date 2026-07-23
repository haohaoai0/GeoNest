import { RecentProjectRecord } from '../model/WorkbenchModels';
import { WorkbenchTextService } from './WorkbenchTextService';

export class WorkbenchRecentProjectService {
  static load(content: string, limit: number): RecentProjectRecord[] {
    let result: RecentProjectRecord[] = [];
    if (content.length === 0 || limit <= 0) {
      return result;
    }
    let lines: string[] = content.split('\n');
    for (let i: number = 0; i < lines.length && result.length < limit; i++) {
      let record: RecentProjectRecord | undefined = WorkbenchTextService.parseRecentProjectLine(lines[i]);
      if (record !== undefined) {
        result.push(record);
      }
    }
    return result;
  }

  static serialize(records: RecentProjectRecord[], limit: number): string {
    let result: string = '';
    for (let i: number = 0; i < records.length && i < limit; i++) {
      let record: RecentProjectRecord = records[i];
      result += WorkbenchTextService.sanitizeLineValue(record.uri) + '\t' +
        WorkbenchTextService.sanitizeLineValue(record.name) + '\t' +
        WorkbenchTextService.sanitizeLineValue(record.owner) + '\t' +
        WorkbenchTextService.sanitizeLineValue(record.crs) + '\t' +
        WorkbenchTextService.sanitizeLineValue(record.workspaceName) + '\n';
    }
    return result;
  }

  static remember(records: RecentProjectRecord[], record: RecentProjectRecord, limit: number): RecentProjectRecord[] {
    let result: RecentProjectRecord[] = [];
    if (record.uri.length === 0 || limit <= 0) {
      return result;
    }
    result.push(record);
    for (let i: number = 0; i < records.length && result.length < limit; i++) {
      let existing: RecentProjectRecord = records[i];
      if (existing.uri !== record.uri) {
        result.push(existing);
      }
    }
    return result;
  }
}
