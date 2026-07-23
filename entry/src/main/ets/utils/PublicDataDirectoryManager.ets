/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { Environment, fileIo as fs } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const LOG_DOMAIN: number = 0x0000;
const LOG_TAG: string = 'PublicDataDirectory';
const PUBLIC_APP_DIRECTORY_NAME: string = 'GeoNest';
const TEST_DATA_SOURCE_NAME: string = 'GeoNestTestData_20260717';
const TEST_DATA_PUBLIC_NAME: string = '测试数据_20260717';

export class PublicDataDirectoryManager {
  public prepare(filesDirectory: string): string {
    if (filesDirectory.length === 0) {
      return '';
    }
    try {
      let documentDirectory: string = Environment.getUserDocumentDir();
      if (documentDirectory.length === 0) {
        return '';
      }
      let publicDirectory: string = documentDirectory + '/' + PUBLIC_APP_DIRECTORY_NAME;
      this.ensureDirectory(publicDirectory);

      let sourceDirectory: string = filesDirectory + '/' + TEST_DATA_SOURCE_NAME;
      if (this.isDirectory(sourceDirectory)) {
        let destinationDirectory: string = publicDirectory + '/' + TEST_DATA_PUBLIC_NAME;
        this.copyDirectory(sourceDirectory, destinationDirectory);
      }
      hilog.info(LOG_DOMAIN, LOG_TAG, 'Public GeoNest directory ready: %{public}s', publicDirectory);
      return publicDirectory;
    } catch (error) {
      let businessError: BusinessError = error as BusinessError;
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'Unable to prepare public directory: %{public}s', businessError.message);
      return '';
    }
  }

  private copyDirectory(sourceDirectory: string, destinationDirectory: string): void {
    this.ensureDirectory(destinationDirectory);
    let names: string[] = fs.listFileSync(sourceDirectory);
    for (let i: number = 0; i < names.length; i++) {
      let name: string = names[i];
      let sourcePath: string = sourceDirectory + '/' + name;
      let destinationPath: string = destinationDirectory + '/' + name;
      if (this.isDirectory(sourcePath)) {
        this.copyDirectory(sourcePath, destinationPath);
      } else if (!this.pathExists(destinationPath)) {
        fs.copyFileSync(sourcePath, destinationPath);
      }
    }
  }

  private ensureDirectory(path: string): void {
    if (this.pathExists(path)) {
      return;
    }
    fs.mkdirSync(path, true);
  }

  private pathExists(path: string): boolean {
    try {
      fs.statSync(path);
      return true;
    } catch (_error) {
      return false;
    }
  }

  private isDirectory(path: string): boolean {
    try {
      let stat: fs.Stat = fs.statSync(path);
      return stat.isDirectory();
    } catch (_error) {
      return false;
    }
  }
}
