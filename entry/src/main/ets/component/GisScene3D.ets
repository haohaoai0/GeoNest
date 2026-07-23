import { Node, Quaternion, Scale3, Scene } from '@kit.ArkGraphics3D';
import { BusinessError } from '@ohos.base';
import { common } from '@kit.AbilityKit';
import { picker } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import fs from '@ohos.file.fs';

interface ThreeDTilesContent {
  uri?: string;
  url?: string;
}

interface ThreeDTilesTile {
  content?: ThreeDTilesContent;
  children?: Array<ThreeDTilesTile>;
}

interface ThreeDTilesDocument {
  root: ThreeDTilesTile;
}

@Component
export struct GisScene3D {
  @State private sceneReady: boolean = false;
  @State private loadingFailed: boolean = false;
  private scene: Scene | null = null;
  private yaw: number = 0;
  private pitch: number = 0;
  private sceneScale: number = 1;
  private lastPanX: number = 0;
  private lastPanY: number = 0;
  private tilesFolderUri: string = '';
  onStatusChanged: (summary: string) => void = (_summary: string): void => {};

  aboutToAppear(): void {
    this.loadScene($rawfile('geonest_terrain.gltf'), 'ArkGraphics 3D 场景已加载');
  }

  private loadScene(uri: ResourceStr, successMessage: string): void {
    this.sceneReady = false;
    this.loadingFailed = false;
    Scene.load(uri).then((loadedScene: Scene): void => {
      if (this.scene !== null) {
        this.scene.destroy();
      }
      this.scene = loadedScene;
      this.sceneReady = true;
      this.loadingFailed = false;
      this.resetSceneView();
      this.onStatusChanged(successMessage);
    }).catch((error: BusinessError): void => {
      this.loadingFailed = true;
      this.onStatusChanged('ArkGraphics 3D 场景加载失败：' + error.code.toString());
    });
  }

  private joinUri(baseUri: string, relativeUri: string): string {
    if (relativeUri.startsWith('file://') || relativeUri.startsWith('content://') ||
      relativeUri.startsWith('datashare://')) {
      return relativeUri;
    }
    let separator: string = baseUri.endsWith('/') ? '' : '/';
    return baseUri + separator + relativeUri;
  }

  private findRenderableContent(tile: ThreeDTilesTile): string {
    if (tile.content !== undefined) {
      let uri: string = tile.content.uri !== undefined ? tile.content.uri :
        (tile.content.url !== undefined ? tile.content.url : '');
      let lower: string = uri.toLowerCase();
      if (lower.endsWith('.gltf') || lower.endsWith('.glb') || lower.endsWith('.b3dm')) {
        return uri;
      }
    }
    if (tile.children !== undefined) {
      for (let i: number = 0; i < tile.children.length; i++) {
        let childUri: string = this.findRenderableContent(tile.children[i]);
        if (childUri.length > 0) {
          return childUri;
        }
      }
    }
    return '';
  }

  private readUint32LittleEndian(buffer: Uint8Array, offset: number): number {
    return buffer[offset] + buffer[offset + 1] * 256 + buffer[offset + 2] * 65536 +
      buffer[offset + 3] * 16777216;
  }

  private extractB3dm(sourceUri: string): string {
    let sourceFile: fs.File | null = null;
    let outputFile: fs.File | null = null;
    try {
      sourceFile = fs.openSync(sourceUri, fs.OpenMode.READ_ONLY);
      let size: number = fs.statSync(sourceFile.fd).size;
      if (size < 28) {
        return '';
      }
      let bytes: Uint8Array = new Uint8Array(size);
      let readLength: number = fs.readSync(sourceFile.fd, bytes.buffer);
      if (readLength < 28 || bytes[0] !== 98 || bytes[1] !== 51 || bytes[2] !== 100 || bytes[3] !== 109) {
        return '';
      }
      let declaredLength: number = this.readUint32LittleEndian(bytes, 8);
      let featureJsonLength: number = this.readUint32LittleEndian(bytes, 12);
      let featureBinaryLength: number = this.readUint32LittleEndian(bytes, 16);
      let batchJsonLength: number = this.readUint32LittleEndian(bytes, 20);
      let batchBinaryLength: number = this.readUint32LittleEndian(bytes, 24);
      let glbOffset: number = 28 + featureJsonLength + featureBinaryLength + batchJsonLength + batchBinaryLength;
      let effectiveLength: number = declaredLength > 0 && declaredLength <= readLength ? declaredLength : readLength;
      if (glbOffset + 12 > effectiveLength || bytes[glbOffset] !== 103 || bytes[glbOffset + 1] !== 108 ||
        bytes[glbOffset + 2] !== 84 || bytes[glbOffset + 3] !== 70) {
        return '';
      }
      let context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      let outputPath: string = context.cacheDir + '/geonest_3dtiles_' + Date.now().toString() + '.glb';
      outputFile = fs.openSync(outputPath,
        fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      let glb: Uint8Array = bytes.slice(glbOffset, effectiveLength);
      fs.writeSync(outputFile.fd, glb.buffer);
      return outputPath;
    } catch (error) {
      return '';
    } finally {
      if (sourceFile !== null) fs.closeSync(sourceFile.fd);
      if (outputFile !== null) fs.closeSync(outputFile.fd);
    }
  }

  private loadTilesFolder(folderUri: string): void {
    let tilesetFile: fs.File | null = null;
    try {
      let tilesetUri: string = this.joinUri(folderUri, 'tileset.json');
      tilesetFile = fs.openSync(tilesetUri, fs.OpenMode.READ_ONLY);
      let size: number = fs.statSync(tilesetFile.fd).size;
      let bytes: Uint8Array = new Uint8Array(size);
      fs.readSync(tilesetFile.fd, bytes.buffer);
      let decoder: util.TextDecoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
      let document: ThreeDTilesDocument = JSON.parse(decoder.decodeToString(bytes, { stream: false })) as
        ThreeDTilesDocument;
      let relativeContentUri: string = this.findRenderableContent(document.root);
      if (relativeContentUri.length === 0) {
        this.loadingFailed = true;
        this.onStatusChanged('3D Tiles 中未找到 ArkGraphics 可渲染的 glTF、GLB 或 B3DM 内容');
        return;
      }
      let contentUri: string = this.joinUri(folderUri, relativeContentUri);
      if (relativeContentUri.toLowerCase().endsWith('.b3dm')) {
        contentUri = this.extractB3dm(contentUri);
        if (contentUri.length === 0) {
          this.loadingFailed = true;
          this.onStatusChanged('B3DM 内嵌 GLB 提取失败');
          return;
        }
      }
      this.tilesFolderUri = folderUri;
      this.loadScene(contentUri, '3D Tiles 已通过 ArkGraphics 3D 加载：' + relativeContentUri);
    } catch (error) {
      this.loadingFailed = true;
      this.onStatusChanged('3D Tiles 读取失败，请确认所选目录包含 tileset.json');
    } finally {
      if (tilesetFile !== null) fs.closeSync(tilesetFile.fd);
    }
  }

  private chooseTilesFolder(): void {
    try {
      let context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      let documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
      let options: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 1;
      options.selectMode = picker.DocumentSelectMode.FOLDER;
      documentPicker.select(options).then((result: Array<string>): void => {
        if (result.length > 0) {
          this.loadTilesFolder(result[0]);
        }
      }).catch((): void => {});
    } catch (error) {
      this.onStatusChanged('当前设备不支持目录选择，无法打开 3D Tiles');
    }
  }

  aboutToDisappear(): void {
    if (this.scene !== null) {
      this.scene.destroy();
      this.scene = null;
    }
    this.sceneReady = false;
  }

  private applySceneTransform(): void {
    if (this.scene === null) {
      return;
    }
    let root: Node | null = this.scene.root;
    if (root === null) {
      return;
    }
    let halfYaw: number = this.yaw * 0.5;
    let halfPitch: number = this.pitch * 0.5;
    let rotation: Quaternion = {
      x: Math.sin(halfPitch) * Math.cos(halfYaw),
      y: Math.cos(halfPitch) * Math.sin(halfYaw),
      z: -Math.sin(halfPitch) * Math.sin(halfYaw),
      w: Math.cos(halfPitch) * Math.cos(halfYaw)
    };
    let scale: Scale3 = { x: this.sceneScale, y: this.sceneScale, z: this.sceneScale };
    root.rotation = rotation;
    root.scale = scale;
    this.scene.renderFrame({ alwaysRender: false });
  }

  private resetSceneView(): void {
    this.yaw = 0;
    this.pitch = 0;
    this.sceneScale = 1;
    this.applySceneTransform();
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      if (this.sceneReady && this.scene !== null) {
        Component3D({ scene: this.scene as Scene, modelType: ModelType.SURFACE })
          .width('100%')
          .height('100%')
          .gesture(
            PanGesture({ distance: 3 })
              .onActionStart((event: GestureEvent): void => {
                this.lastPanX = event.offsetX;
                this.lastPanY = event.offsetY;
              })
              .onActionUpdate((event: GestureEvent): void => {
                let deltaX: number = event.offsetX - this.lastPanX;
                let deltaY: number = event.offsetY - this.lastPanY;
                this.lastPanX = event.offsetX;
                this.lastPanY = event.offsetY;
                this.yaw += deltaX * 0.008;
                this.pitch += deltaY * 0.008;
                if (this.pitch > 1.2) this.pitch = 1.2;
                if (this.pitch < -1.2) this.pitch = -1.2;
                this.applySceneTransform();
              })
          )
          .gesture(
            PinchGesture({ fingers: 2 })
              .onActionUpdate((event: GestureEvent): void => {
                if (event.scale > 0.5 && event.scale < 2.0) {
                  this.sceneScale = this.sceneScale * event.scale;
                  if (this.sceneScale < 0.2) this.sceneScale = 0.2;
                  if (this.sceneScale > 8) this.sceneScale = 8;
                  this.applySceneTransform();
                }
              })
          )
      } else if (this.loadingFailed) {
        Text($r('app.string.gn_scene_3d_load_failed'))
          .fontSize(14)
          .fontColor($r('app.color.gn_orange_700'))
          .margin({ top: 28, right: 28 })
      } else {
        LoadingProgress()
          .width(36)
          .height(36)
          .margin({ top: 28, right: 28 })
      }
      Row({ space: 8 }) {
        Button('打开 3D Tiles', { type: ButtonType.Capsule, stateEffect: true })
          .height(30)
          .fontSize(12)
          .onClick((): void => {
            this.chooseTilesFolder();
          })
        Button($r('app.string.gn_scene_3d_reset'), { type: ButtonType.Capsule, stateEffect: true })
          .height(30)
          .fontSize(12)
          .onClick((): void => {
            this.resetSceneView();
          })
      }
      .margin({ top: 16, right: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.gn_pane_alt'))
  }
}
