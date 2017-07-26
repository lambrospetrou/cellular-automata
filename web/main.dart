// Copyright (c) 2017, Lambros Petrou. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:html' as html;
import 'package:stagexl/stagexl.dart' as sxl;

const STAGE_WIDTH = 1280;
const STAGE_HEIGHT = 800;

void main() {

  sxl.StageOptions options = new sxl.StageOptions()
    ..backgroundColor = sxl.Color.WhiteSmoke
    ..antialias = true
    ..renderEngine = sxl.RenderEngine.WebGL;

  var canvas = html.querySelector('#stage');
  var stage = new sxl.Stage(canvas, width: STAGE_WIDTH, height: STAGE_HEIGHT, options: options);
  var renderLoop = new sxl.RenderLoop();
  renderLoop.addStage(stage);

  Painter painter = new Painter(stage);
  html.querySelector('#tool-r').onClick.listen((evt) {
    if (painter != null) {
      painter.stopAndClear();
      painter = new Painter(stage);
    }
  });
}

class Painter {
  final sxl.Stage stage;
  Timer timer;

  Painter(this.stage) {
    sxl.BitmapData canvasBitmapData = new sxl.BitmapData(STAGE_WIDTH, STAGE_HEIGHT);
    sxl.BitmapDataUpdateBatch canvasBitmapDataBuffer = new sxl.BitmapDataUpdateBatch(canvasBitmapData);
    sxl.Bitmap drawingCache = new sxl.Bitmap(canvasBitmapData);
    drawingCache.addTo(stage);

    const TIMEOUT = const Duration(milliseconds: 33);

    print('starting timer');
    int x = 0;
    timer = new Timer.periodic(TIMEOUT, (Timer timer) {
      if (x>STAGE_WIDTH) {
        timer.cancel();
        print('finished timer!');
        return;
      }
      for (var end=x+10; x<end; x++) {
        canvasBitmapDataBuffer.setPixel32(x, 10, sxl.Color.CadetBlue);
      }
      canvasBitmapDataBuffer.update();
    });
  }

  void stopAndClear() {
    timer.cancel();
    stage.removeChildren();
  }
}
