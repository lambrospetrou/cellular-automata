// Copyright (c) 2017, Lambros Petrou. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:math';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:stagexl/stagexl.dart' as sxl;

class RequestConfig {
  int _width;
  int _height;

  RequestConfig.fromURL(Uri uri) : _width = -1, _height = -1 {
    if (!uri.hasQuery) {return;}
    
    Map<String, String> qps = uri.queryParameters;
    if (qps['w'] != null) { _width = int.parse(qps['w']); }
    if (qps['h'] != null) { _height = int.parse(qps['h']); }
  }

  int width(int withDefault) {
    if (_width < 0) {
      return withDefault;
    }
    return _width;
  }
  int height(int withDefault) {
    if (_height < 0) {
      return withDefault;
    }
    return _height;
  }
}

void main() {
  final WINDOW_WIDTH = html.window.innerWidth;
  final WINDOW_HEIGHT = html.window.innerHeight;
  print('Window width $WINDOW_WIDTH and height $WINDOW_HEIGHT');

  print(html.window.location.toString());

  RequestConfig config = new RequestConfig.fromURL(Uri.parse(html.window.location.toString()));

  final STAGE_WIDTH = config.width(150);
  final STAGE_HEIGHT = config.height((STAGE_WIDTH * WINDOW_HEIGHT / WINDOW_WIDTH).ceil());

  html.CanvasElement canvas = (html.querySelector('#stage') as html.CanvasElement);
  canvas.height = STAGE_HEIGHT;
  canvas.width = STAGE_WIDTH;

  // sxl.StageOptions options = new sxl.StageOptions()
  //   ..backgroundColor = sxl.Color.Tomato
  //   ..antialias = true
  //   ..stageScaleMode = sxl.StageScaleMode.SHOW_ALL
  //   ..stageAlign = sxl.StageAlign.NONE
  //   ..renderEngine = sxl.RenderEngine.Canvas2D;
  //var stage = new sxl.Stage(canvas, width: STAGE_WIDTH, height: STAGE_HEIGHT, options: options);
  //var renderLoop = new sxl.RenderLoop();
  //renderLoop.addStage(stage);

  CellularPainter painter = new CellularPainter(null, canvas);
  html.querySelector('#tool-r').onClick.listen((evt) {
    if (painter != null) {
      painter.stopAndClear();
    }
    painter = new CellularPainter(null, canvas);
  });

  html.querySelector('#tool-s').onClick.listen((evt) {
    if (painter != null) {
      painter.stopAndClear();
      painter = null;
    }
  });

}

class CellularPainter {
  final sxl.Stage _stage;
  sxl.BitmapDataUpdateBatch _canvasBitmapDataBuffer;

  final html.CanvasElement _canvas;
  final html.CanvasRenderingContext2D _canvasCtx;

  CellularEffectCalculator _cellularEffectCalculator;

  int _STAGE_WIDTH, _STAGE_HEIGHT;

  bool _isStopped = false;

  CellularPainter(this._stage, this._canvas) : 
    _canvasCtx = (_canvas.getContext('2d') as html.CanvasRenderingContext2D) {
    // this has the size of the canvas
    //_STAGE_WIDTH = this._stage.stageWidth;
    //_STAGE_HEIGHT = this._stage.stageHeight;
    //_STAGE_WIDTH = this._stage.contentRectangle.width.floor();
    //_STAGE_HEIGHT = this._stage.contentRectangle.height.floor();
    //print('Stage contentRectangle width $_STAGE_WIDTH and height $_STAGE_HEIGHT');
    _STAGE_WIDTH = _canvas.width;
    _STAGE_HEIGHT = _canvas.height;
    print('Canvas width $_STAGE_WIDTH and height $_STAGE_HEIGHT');

    // sxl.BitmapData canvasBitmapData =
    //     new sxl.BitmapData(_STAGE_WIDTH, _STAGE_HEIGHT);
    // _canvasBitmapDataBuffer = new sxl.BitmapDataUpdateBatch(canvasBitmapData);
    // sxl.Bitmap drawingCache = new sxl.Bitmap(canvasBitmapData);
    // drawingCache.addTo(_stage);
    // Get BitmapData from canvas hint
    //var canvasRenderTexture = new sxl.RenderTexture.fromCanvasElement(_canvas);
    //new sxl.BitmapData.fromRenderTextureQuad(canvasRenderTexture.quad.withPixelRatio(1.0));

    _cellularEffectCalculator = new CellularEffectCalculator(_STAGE_WIDTH, _STAGE_HEIGHT);

    run();
  }

  void _tickUpdate(num delta) {
    //print('Tick: $delta');
    if (_isStopped) return;
    // TICK UPDATE START

    html.ImageData imgData = _canvasCtx.getImageData(0, 0, _canvas.width, _canvas.height);
    
    _cellularEffectCalculator.nextTick(imgData);

    _canvasCtx.putImageData(imgData, 0, 0);

    //_cellularEffectCalculator.nextTick(_canvasBitmapDataBuffer);
    //_canvasBitmapDataBuffer.update();

    // TICK UPDATE END
    run();
  }

  void run() {
    html.window.animationFrame.then(_tickUpdate);
  }

  void stopAndClear() {
    _isStopped = true;
    if (_stage != null) {
      _stage.removeChildren();
    }
  }
}

class Cell {
  double r, g, b;
  double rVel, gVel, bVel;

  double bufferR, bufferG, bufferB;
  double bufferRVel, bufferGVel, bufferBVel;

  List<int> neighborsIndex;

  Cell()
      : r = 0.0,
        g = 0.0,
        b = 0.0,
        rVel = 0.0,
        gVel = 0.0,
        bVel = 0.0,
        bufferR = 0.0,
        bufferG = 0.0,
        bufferB = 0.0,
        bufferRVel = 0.0,
        bufferGVel = 0.0,
        bufferBVel = 0.0 {}
  Cell.fromRGB(this.r, this.g, this.b)
      : rVel = 0.0,
        gVel = 0.0,
        bVel = 0.0,
        bufferR = r,
        bufferG = g,
        bufferB = b,
        bufferRVel = 0.0,
        bufferGVel = 0.0,
        bufferBVel = 0.0 {}
}

class CellularEffectCalculator {
  static const ease = 0.67;
  static const velMax = 255;
  static const minDist = 8;
  static const minDistSquare = minDist * minDist;
  static const sepNormMag = 4;

  final _GRID_WIDTH;
  final _GRID_HEIGHT;
  final _CELL_WIDTH;
  final _CELL_HEIGHT;
  final _TOTAL_CELLS;

  final _GRID_RIGHTMOST;
  final _GRID_BOTTOMMOST;

  Stopwatch _stopwatch = new Stopwatch();
  Stopwatch _stopwatch2 = new Stopwatch();

  List<Cell>_cells;

  Uint8ClampedList _arrayBuffer;
  Uint32List _rgbData;

  CellularEffectCalculator(this._GRID_WIDTH, this._GRID_HEIGHT)
      : _CELL_WIDTH = 1,
        _CELL_HEIGHT = 1,
        _TOTAL_CELLS = _GRID_WIDTH * _GRID_HEIGHT,
        _GRID_RIGHTMOST = _GRID_WIDTH - 1,
        _GRID_BOTTOMMOST = _GRID_HEIGHT - 1 {
    _initCells();
    // buffer to hold the output
    _arrayBuffer = new Uint8ClampedList(_TOTAL_CELLS*4);
    _rgbData = new Uint32List.view(_arrayBuffer.buffer);
  }

  List<int> _calculateNeighbors(int x, y) {
    List<int> n = [];
    if (x > 0) {
      n.add(y * _GRID_WIDTH + x - 1);
    }
    if (x < _GRID_RIGHTMOST) {
      n.add(y * _GRID_WIDTH + x + 1);
    }
    if (y > 0) {
      n.add((y - 1) * _GRID_WIDTH + x);
    }
    if (y < _GRID_BOTTOMMOST) {
      n.add((y + 1) * _GRID_WIDTH + x);
    }
    return n;
  }

  void _initCells() {
    _cells = new List<Cell>();

    Random random = new Random();
    for (int y = 0; y < _GRID_HEIGHT; y++) {
      for (int x = 0; x < _GRID_WIDTH; x++) {
        Cell cell = new Cell.fromRGB(random.nextDouble() * 255,
            random.nextDouble() * 255, random.nextDouble() * 255);
        cell.neighborsIndex = _calculateNeighbors(x, y);
        _cells.add(cell);
      }
    }
  }

  void resetCells() {
    Random random = new Random();
    _cells.forEach((cell) {
      cell.r = cell.bufferR = random.nextDouble() * 255;
      cell.g = cell.bufferG = random.nextDouble() * 255;
      cell.b = cell.bufferB = random.nextDouble() * 255;
      cell.rVel = cell.gVel = cell.bVel = 0.0;
      cell.bufferRVel = cell.bufferGVel = cell.bufferBVel = 0.0;
    });
  }

  void ensureColorBounds(Cell cell) {
    //bounce colors off of color cube boundaries
    if (cell.bufferR < 0) {
      cell.bufferR = 0.0;
      cell.bufferRVel *= -1;
    } else if (cell.bufferR > 255) {
      cell.bufferR = 255.0;
      cell.bufferRVel *= -1;
    }
    if (cell.bufferG < 0) {
      cell.bufferG = 0.0;
      cell.bufferGVel *= -1;
    } else if (cell.bufferG > 255) {
      cell.bufferG = 255.0;
      cell.bufferGVel *= -1;
    }
    if (cell.bufferB < 0) {
      cell.bufferB = 0.0;
      cell.bufferBVel *= -1;
    } else if (cell.bufferB > 255) {
      cell.bufferB = 255.0;
      cell.bufferBVel *= -1;
    }
  }

  void nextTick(html.ImageData imageData) {
    //print('nextTick()::');
    _stopwatch.reset();
    _stopwatch.start();

    _cells.forEach((cell) {
      double rAve = 0.0,
          gAve = 0.0,
          bAve = 0.0,
          rVelAve = 0.0,
          gVelAve = 0.0,
          bVelAve = 0.0,
          rSep = 0.0,
          gSep = 0.0,
          bSep = 0.0;
      double dr, dg, db;

      cell.neighborsIndex.forEach((nidx) {
        Cell neighbor = _cells[nidx];
        rAve += neighbor.r;
        gAve += neighbor.g;
        bAve += neighbor.b;
        rVelAve += neighbor.rVel;
        gVelAve += neighbor.gVel;
        bVelAve += neighbor.bVel;
        dr = cell.r - neighbor.r;
        dg = cell.g - neighbor.g;
        db = cell.b - neighbor.b;
        if (dr * dr + dg * dg + db * db < minDistSquare) {
          rSep += dr;
          gSep += dg;
          bSep += db;
        }
      });

      double f = 1 / cell.neighborsIndex.length;
      rAve *= f;
      gAve *= f;
      bAve *= f;
      rVelAve *= f;
      gVelAve *= f;
      bVelAve *= f;

      //normalize separation vector
      if ((rSep != 0) || (gSep != 0) || (bSep != 0)) {
        double sepMagRecip =
            sepNormMag / sqrt(rSep * rSep + gSep * gSep + bSep * bSep);
        rSep *= sepMagRecip;
        gSep *= sepMagRecip;
        bSep *= sepMagRecip;
      }

      //Update velocity by combining separation, alignment and cohesion effects. Change velocity only by 'ease' ratio.
      cell.bufferRVel +=
          ease * (rSep + rVelAve + rAve - cell.r - cell.bufferRVel);
      cell.bufferGVel +=
          ease * (gSep + gVelAve + gAve - cell.g - cell.bufferGVel);
      cell.bufferBVel +=
          ease * (bSep + bVelAve + bAve - cell.b - cell.bufferBVel);

      //update colors according to color velocities
      cell.bufferR += cell.bufferRVel;
      cell.bufferG += cell.bufferGVel;
      cell.bufferB += cell.bufferBVel;

      ensureColorBounds(cell);
    }); // end for each cell

    //_stopwatch.stop();
    //print('nextTick()::calc:: ${_stopwatch.elapsedMilliseconds}ms');

    // _stopwatch.reset(); _stopwatch.start();
    // _stopwatch2.reset(); _stopwatch2.start();
    Cell cell;
    for (var idx=0; idx<_TOTAL_CELLS; idx++) {
      cell = _cells[idx];

      //_stopwatch2.start();
      // Copy buffer values into primary!
      cell.r = cell.bufferR;
      cell.g = cell.bufferG;
      cell.b = cell.bufferB;
      cell.rVel = cell.bufferRVel;
      cell.gVel = cell.bufferGVel;
      cell.bVel = cell.bufferBVel;
      //_stopwatch2.stop();

      // Copy data to output
      _rgbData[idx] = 0xFF000000 | (cell.r.toInt() << 16) | (cell.g.toInt() << 8) | (cell.b.toInt());
    };
    imageData.data.setAll(0, _arrayBuffer);

    _stopwatch.stop();
    //print('nextTick()::copy:: ${_stopwatch2.elapsedMilliseconds}ms');
    //print('nextTick()::copy+setpixel+imgData.setAll:: ${_stopwatch.elapsedMilliseconds}ms');
    print('nextTick()::total:: ${_stopwatch.elapsedMilliseconds}ms');
  }
}
