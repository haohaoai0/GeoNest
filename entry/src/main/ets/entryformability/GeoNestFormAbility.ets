import { Want } from '@kit.AbilityKit';
import { formBindingData, FormExtensionAbility, formInfo, formProvider } from '@kit.FormKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { GeoNestFormStateStore } from '../utils/GeoNestFormStateStore';

const GEONEST_FORM_TAG: string = 'GeoNestFormAbility';
const GEONEST_FORM_DOMAIN: number = 0xF817;

export default class GeoNestFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    let formId: string = want.parameters?.[formInfo.FormParam.IDENTITY_KEY] as string;
    GeoNestFormStateStore.getInstance().registerFormId(this.context.filesDir, formId);
    return GeoNestFormStateStore.getInstance().createBindingData(this.context.filesDir);
  }

  onUpdateForm(formId: string): void {
    let data: formBindingData.FormBindingData =
      GeoNestFormStateStore.getInstance().createBindingData(this.context.filesDir);
    formProvider.updateForm(formId, data).catch((error: BusinessError) => {
      hilog.warn(GEONEST_FORM_DOMAIN, GEONEST_FORM_TAG,
        'update form failed. code=%{public}d message=%{public}s', error.code, error.message);
    });
  }

  onFormEvent(formId: string, message: string): void {
    hilog.info(GEONEST_FORM_DOMAIN, GEONEST_FORM_TAG,
      'form event. formId=%{public}s message=%{public}s', formId, message);
  }

  onRemoveForm(formId: string): void {
    GeoNestFormStateStore.getInstance().unregisterFormId(this.context.filesDir, formId);
  }

  onAcquireFormState(want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }
}
