import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { notificationManager } from '@kit.NotificationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  GIS_PROCESSING_TASK_CANCEL_REQUESTED,
  GIS_PROCESSING_TASK_CANCELED,
  GIS_PROCESSING_TASK_FAILED,
  GIS_PROCESSING_TASK_QUEUED,
  GIS_PROCESSING_TASK_SUCCEEDED,
  GisProcessingTaskSnapshot
} from '../model/GeoNestModels';

const PROCESSING_NOTIFICATION_TAG: string = 'GeoNestNotification';
const PROCESSING_NOTIFICATION_DOMAIN: number = 0xF816;
const PROCESSING_NOTIFICATION_ID: number = 23001;
const PROCESSING_NOTIFICATION_LABEL: string = 'geonest-processing';

export class ProcessingNotificationManager {
  private static instance: ProcessingNotificationManager | null = null;

  private slotReady: boolean = false;
  private permissionPrompted: boolean = false;
  private lastTaskId: string = '';
  private lastProgressBucket: number = -1;
  private lastState: string = '';

  private constructor() {}

  public static getInstance(): ProcessingNotificationManager {
    if (ProcessingNotificationManager.instance === null) {
      ProcessingNotificationManager.instance = new ProcessingNotificationManager();
    }
    return ProcessingNotificationManager.instance;
  }

  public notifySnapshot(context: common.UIAbilityContext, snapshot: GisProcessingTaskSnapshot, toolTitle: string,
    force: boolean = false): void {
    if (snapshot.taskId.length === 0) {
      return;
    }
    this.ensureReady(context);
    let progressBucket: number = Math.floor(this.safeProgress(snapshot.progress) / 5) * 5;
    let shouldPublish: boolean = force || snapshot.done || snapshot.taskId !== this.lastTaskId ||
      snapshot.state !== this.lastState || progressBucket !== this.lastProgressBucket;
    if (!shouldPublish) {
      return;
    }
    this.lastTaskId = snapshot.taskId;
    this.lastProgressBucket = progressBucket;
    this.lastState = snapshot.state;
    let request: notificationManager.NotificationRequest =
      this.buildNotificationRequest(snapshot, toolTitle, this.notificationBody(snapshot));
    notificationManager.publish(request).catch((error: BusinessError) => {
      hilog.warn(PROCESSING_NOTIFICATION_DOMAIN, PROCESSING_NOTIFICATION_TAG,
        'publish notification failed. code=%{public}d message=%{public}s', error.code, error.message);
    });
  }

  public notifyCancelRequested(context: common.UIAbilityContext, taskId: string, toolTitle: string): void {
    if (taskId.length === 0) {
      return;
    }
    this.ensureReady(context);
    let request: notificationManager.NotificationRequest =
      this.buildTextNotification('GeoNest 后台任务：' + toolTitle, '正在请求取消，临时成果会自动清理。', true);
    notificationManager.publish(request).catch((error: BusinessError) => {
      hilog.warn(PROCESSING_NOTIFICATION_DOMAIN, PROCESSING_NOTIFICATION_TAG,
        'publish cancel notification failed. code=%{public}d message=%{public}s', error.code, error.message);
    });
  }

  private ensureReady(context: common.UIAbilityContext): void {
    if (!this.slotReady) {
      notificationManager.addSlot(notificationManager.SlotType.SERVICE_INFORMATION).then(() => {
        this.slotReady = true;
      }).catch((error: BusinessError) => {
        hilog.warn(PROCESSING_NOTIFICATION_DOMAIN, PROCESSING_NOTIFICATION_TAG,
          'add notification slot failed. code=%{public}d message=%{public}s', error.code, error.message);
      });
    }
    if (this.permissionPrompted) {
      return;
    }
    this.permissionPrompted = true;
    notificationManager.isNotificationEnabled().then((enabled: boolean) => {
      if (!enabled) {
        notificationManager.requestEnableNotification(context).catch((error: BusinessError) => {
          hilog.warn(PROCESSING_NOTIFICATION_DOMAIN, PROCESSING_NOTIFICATION_TAG,
            'request notification permission failed. code=%{public}d message=%{public}s',
            error.code, error.message);
        });
      }
    }).catch((error: BusinessError) => {
      hilog.warn(PROCESSING_NOTIFICATION_DOMAIN, PROCESSING_NOTIFICATION_TAG,
        'query notification enabled failed. code=%{public}d message=%{public}s', error.code, error.message);
    });
  }

  private buildNotificationRequest(snapshot: GisProcessingTaskSnapshot, toolTitle: string,
    body: string): notificationManager.NotificationRequest {
    let title: string = 'GeoNest 后台任务：' + toolTitle;
    return this.buildTextNotification(title, body, !snapshot.done);
  }

  private buildTextNotification(title: string, text: string, ongoing: boolean): notificationManager.NotificationRequest {
    let request: notificationManager.NotificationRequest = {
      id: PROCESSING_NOTIFICATION_ID,
      label: PROCESSING_NOTIFICATION_LABEL,
      notificationSlotType: notificationManager.SlotType.SERVICE_INFORMATION,
      isOngoing: ongoing,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: title,
          text: text,
          additionalText: '打开 GeoNest 查看详情或取消任务'
        }
      }
    };
    return request;
  }

  private notificationBody(snapshot: GisProcessingTaskSnapshot): string {
    let progress: number = this.safeProgress(snapshot.progress);
    if (snapshot.cancelRequested || snapshot.state === GIS_PROCESSING_TASK_CANCEL_REQUESTED) {
      return '正在取消 · ' + progress.toString() + '%';
    }
    if (snapshot.state === GIS_PROCESSING_TASK_QUEUED) {
      return '排队中 · 等待 QGIS 后台任务启动';
    }
    if (snapshot.state === GIS_PROCESSING_TASK_SUCCEEDED) {
      return '完成 · 100%';
    }
    if (snapshot.state === GIS_PROCESSING_TASK_CANCELED) {
      return '已取消 · 临时成果已清理';
    }
    if (snapshot.state === GIS_PROCESSING_TASK_FAILED) {
      return snapshot.message.length > 0 ? '失败 · ' + snapshot.message : '失败 · 请返回 GeoNest 查看原因';
    }
    let stageText: string = snapshot.stage.length > 0 ? snapshot.stage : '正在处理';
    return stageText + ' · ' + progress.toString() + '%';
  }

  private safeProgress(value: number): number {
    let progress: number = Math.floor(value);
    if (progress < 0) {
      return 0;
    }
    if (progress > 100) {
      return 100;
    }
    return progress;
  }
}
