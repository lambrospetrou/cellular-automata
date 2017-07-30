// Copyright (c) 2017, Lambros Petrou. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:html' as html;
import 'package:stagexl/stagexl.dart' as sxl;

void main() {
  final WINDOW_WIDTH = html.window.innerWidth;
  final WINDOW_HEIGHT = html.window.innerHeight;
  print('Window width $WINDOW_WIDTH and height $WINDOW_HEIGHT');

  sxl.StageOptions options = new sxl.StageOptions()
    ..backgroundColor = sxl.Color.Tomato
    ..antialias = true
    ..renderEngine = sxl.RenderEngine.WebGL;

  var canvas = html.querySelector('#stage');
  var stage = new sxl.Stage(canvas,
      height: WINDOW_HEIGHT, width: WINDOW_WIDTH, options: options);
  var renderLoop = new sxl.RenderLoop();
  renderLoop.addStage(stage);

  CellularPainter painter = new CellularPainter(stage);
  html.querySelector('#tool-r').onClick.listen((evt) {
    if (painter != null) {
      painter.stopAndClear();
      painter = new CellularPainter(stage);
    }
  });
}

class CellularPainter {
  final sxl.Stage _stage;
  sxl.BitmapDataUpdateBatch _canvasBitmapDataBuffer;

  int _STAGE_WIDTH, _STAGE_HEIGHT;

  bool _isStopped = false;

  CellularPainter(this._stage) {
    _STAGE_WIDTH = this._stage.stageWidth;
    _STAGE_HEIGHT = this._stage.stageHeight;

    print('Stage width $_STAGE_WIDTH and height $_STAGE_HEIGHT');

    sxl.BitmapData canvasBitmapData =
        new sxl.BitmapData(_STAGE_WIDTH, _STAGE_HEIGHT);
    _canvasBitmapDataBuffer = new sxl.BitmapDataUpdateBatch(canvasBitmapData);
    sxl.Bitmap drawingCache = new sxl.Bitmap(canvasBitmapData);
    drawingCache.addTo(_stage);
    run();
  }

  int _x = 0;

  void _tickUpdate(num delta) {
    print('Tick: $delta');
    if (_isStopped) return;
    // TICK UPDATE START

    if (_x > _STAGE_WIDTH) {
      print('finished!');
      return;
    }
    for (var end = _x + 10; _x < end; _x++) {
      _canvasBitmapDataBuffer.setPixel32(_x, 10, sxl.Color.CadetBlue);
    }
    _canvasBitmapDataBuffer.update();

    // TICK UPDATE END
    run();
  }

  void run() {
    html.window.animationFrame.then(_tickUpdate);
  }

  void stopAndClear() {
    _isStopped = true;
    _stage.removeChildren();
  }
}
