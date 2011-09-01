module GUI.Histogram (
    HistogramView,
    histogramViewNew,
    histogramViewSetHECs
 ) where

import Events.HECs

import Graphics.UI.Gtk
import Graphics.Rendering.Cairo as C

import qualified Graphics.Rendering.Chart as Chart
import qualified Graphics.Rendering.Chart.Renderable as ChartR
import qualified Graphics.Rendering.Chart.Gtk as ChartG

import Data.Accessor
import Data.IORef
import qualified Data.IntMap as IM

data HistogramView = HistogramView {

       hecsIORef :: IORef (Maybe HECs)

     }

histogramViewSetHECs :: HistogramView -> Maybe HECs -> IO ()
histogramViewSetHECs HistogramView{..} mhecs =
  writeIORef hecsIORef mhecs

histogramViewNew :: Builder -> IO HistogramView
histogramViewNew builder = do
  let getWidget cast = builderGetObject builder cast
  histogramDrawingArea <- getWidget castToDrawingArea "histogram_drawingarea"

  hecsIORef <- newIORef Nothing
  let histogramView = HistogramView{..}

  -- Program the callback for the capability drawingArea
  on histogramDrawingArea exposeEvent $ do
     liftIO $ do
       maybeEventArray <- readIORef hecsIORef
       -- Check if an event trace has been loaded
       case maybeEventArray of
         Nothing   -> return True
         Just hecs -> renderViewHistogram histogramDrawingArea hecs

  return histogramView

renderViewHistogram :: DrawingArea -> HECs -> IO Bool
renderViewHistogram historamDrawingArea hecs = do
  let intDoub :: Integral a => a -> Double
      intDoub = fromIntegral
      histo :: [(Int, Timestamp)] -> [(Int, Timestamp)]
      histo durs = IM.toList $ IM.fromListWith (+) durs
      inRange :: [(Timestamp, Int, Timestamp)] -> [(Int, Timestamp)]
      inRange xs = [(logdur, dur) | (start, logdur, dur) <- xs]  -- TODO

      plot xs =
        let layout = Chart.layout1_plots ^= [ Left (Chart.plotBars bars) ]
                     $ Chart.defaultLayout1 :: Chart.Layout1 Double Double
            bars = Chart.plot_bars_values ^= barvs
                   $ Chart.defaultPlotBars
            barvs = [(intDoub t, [intDoub height]) | (t, height) <- hs]
            hs = histo (inRange xs)
        in layout
      renderable = ChartR.toRenderable (plot (durHistogram hecs))
  ChartG.updateCanvas renderable historamDrawingArea
