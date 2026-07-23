import { deviceInfo } from '@kit.BasicServicesKit';

class DeviceCheckState {
  detected: boolean = false;
  isCollaborationCapable: boolean = false;
}

const state: DeviceCheckState = new DeviceCheckState();

const API_VERSION_6_1_0: number = 60100;

function checkApiVersion(): boolean {
  try {
    const v: number = deviceInfo.distributionOSApiVersion;
    return v >= API_VERSION_6_1_0;
  } catch (_) {
    return false;
  }
}

export function isCollaborationCapable(): boolean {
  if (state.detected) {
    return state.isCollaborationCapable;
  }
  state.detected = true;
  try {
    const t: string = deviceInfo.deviceType;
    const isHighApi: boolean = checkApiVersion();

    if (isHighApi) {
      state.isCollaborationCapable = (t === 'phone' || t === 'tablet' || t === '2in1' || t === 'tv');
    } else {
      state.isCollaborationCapable = (t === 'tablet' || t === '2in1');
    }
  } catch (_) {
    state.isCollaborationCapable = false;
  }
  return state.isCollaborationCapable;
}
