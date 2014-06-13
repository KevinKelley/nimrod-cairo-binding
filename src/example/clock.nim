#
#  Cairo SDL clock. Shows how to use Cairo with SDL.
#  Made by Writser Cleveringa, based upon code from Eric Windisch.
#  Minor code clean up by Chris Nystrom (5/21/06) and converted to cairo-sdl
#  by Chris Wilson and converted to cairosdl by M Joonas Pihlaja.
#  Ported to Nimrod by Kevin Kelley.
#

import times, math
from cairo import nil   # force fully-qualified names
from SDL2 import nil


proc error(msg: string) =
  # on error, display a msg along with any exception trace, then quit.
  echo msg
  let ex = getCurrentException()
  if ex != nil:
    echo getCurrentExceptionMsg()
    echo ex.repr
  system.quit 1


proc rect(x,y,w,h:int): SDL2.TRect = 
  # convenience-constructor 
  Rect(cint(x), cint(y), cint(w), cint(h))


proc mkSDLSurface(width, height: int): SDL2.PSurface = 
  # create an SDL2 surface: an array of pixels in memory with
  # a layout that cairo can write.
  return SDL2.CreateRGBSurface(
    cint 0, 
    cint width,
    cint height,
    cint 32,
    cint 0x00FF0000, #CAIROSDL_RMASK,
    cint 0x0000FF00, #CAIROSDL_GMASK,
    cint 0x000000FF, #CAIROSDL_BMASK, 
    cint 0)          #CAIROSDL_AMASK)


proc surface_create(sdl_surface: SDL2.PSurface): ptr cairo.Tsurface =
  # create a cairo surface that wraps the SDL2 surface's pixel memory,
  # so that cairo can write directly to it.
  #
  # The caller is expected to have locked the surface (_if_ it
  #  needs locking) so that sdl_surface->pixels is valid and
  #  constant for the lifetime of the cairo_cairo.Tsurface.  However,
  #  we're told not to call any OS functions when a surface is
  #  locked, so we really shouldn't call
  #  cairo_image_surface_create () as it will malloc, so really
  #  if the surface needs locking this shouldn't be used.
  # 
  #  However, it turns out malloc is actually safe on many (all?)
  #  platforms so we'll just go ahead anyway. 
  #
  proc `==`(a: uint, b: int): bool = cast[int](a) == b
  assert sdl_surface.format.BytesPerPixel == 4
  assert sdl_surface.format.BitsPerPixel == 32
  assert sdl_surface.format.Rmask == 0x00FF0000
  assert sdl_surface.format.Gmask == 0x0000FF00
  assert sdl_surface.format.Bmask == 0x000000FF
  assert sdl_surface.format.Amask == 0x00000000

  # Amask==Ff000000 could be supported, by pre-multiplying and un-pre-multiplying
  # pixels.  Cairo uses pre-multiplied alpha, SDL not.
  # Here the SDL surface is the paint for a non-transparent Window, so it doesn't
  # need alpha. (transparency of cairo prims works just fine, it all just ends up
  # blended onto a non-transparent SDL surface)

  return cairo.image_surface_create_for_data( cast[ptr cuchar](sdl_surface.pixels), 
                                              cairo.CAIRO_FORMAT_RGB24,
                                              cint sdl_surface.w, 
                                              cint sdl_surface.h, 
                                              cint sdl_surface.pitch )


proc createCairoContext*(sdl_surface: SDL2.PSurface): ptr cairo.Tcairo = 
  # creates a cairo drawing-context for the SDL surface
  var surface: ptr cairo.Tsurface = surface_create(sdl_surface)
  var cr: ptr cairo.Tcairo = cairo.create(surface)
  cairo.surface_destroy(surface)
  return cr

proc destroyCairoContext*(cr: ptr cairo.Tcairo) {.cdecl.} = 
  # flushes cairo and deletes the cairo context
  cairo.destroy(cr)  


# Draws a clock on a normalized Cairo context 

proc draw*(cr: ptr cairo.Tcairo) = 
  const TwoPi = PI * 2.0

  var
    tm: TTimeInfo = getTime().getLocalTime()
    second: float = float tm.second
    minute: float = float tm.minute
    hour  : float = float tm.hour mod 12

  # convert time values to angles
  second = second * TwoPi / 60.0
  minute = minute * TwoPi / 60.0
  hour   = hour   * TwoPi / 12.0

  # Fill the background with white. 
  cairo.set_source_rgb(cr, 1.0,1.0,1.0)
  cairo.paint(cr)

  # the clock hands are just lines with round end-caps
  cairo.set_line_cap(cr, cairo.CAIRO_LINE_CAP_ROUND)
  cairo.set_line_width(cr, 0.1)

  # translate to the center of the rendering context and draw a black 
  # clock outline 
  cairo.set_source_rgb(cr, 0, 0, 0)
  cairo.translate(cr, 0.5, 0.5)
  cairo.arc(cr, 0, 0, 0.4, 0, TwoPi)
  cairo.stroke(cr)

  # draw a white dot on the current second. 
  cairo.set_source_rgba(cr, 1, 1, 1, 0.6)
  cairo.arc(cr, sin(second) * 0.4, 
              -(cos(second) * 0.4), 
              0.05, 0, TwoPi)
  cairo.fill(cr)

  # draw the minutes indicator 
  cairo.set_source_rgba(cr, 0.2, 0.2, 1, 0.6)
  cairo.move_to(cr, 0, 0)
  cairo.line_to(cr, sin(minute) * 0.4, 
                  -(cos(minute) * 0.4))
  cairo.stroke(cr)

  # draw the hours indicator      
  cairo.move_to(cr, 0, 0)
  cairo.line_to(cr, sin(hour) * 0.2, 
                  -(cos(hour) * 0.2))
  cairo.stroke(cr)


# Shows how to draw with Cairo on SDL surfaces 

proc draw_screen*(surface: SDL2.PSurface) = 
  var cr: ptr cairo.Tcairo
  var status: cairo.Tstatus
  # Create a cairo drawing context, normalize it and draw a clock. 
  var ok: bool = SDL2.LockSurface(surface) == 0
  cr = createCairoContext(surface)
  cairo.scale(cr, cdouble(surface.w), cdouble(surface.h))
  draw(cr)
  status = cairo.status(cr)
  destroyCairoContext(cr)
  SDL2.UnlockSurface(surface)
  
  #surface is drawn and ready for painting to screen

  #  check for cairo errors
  if status != cairo.CAIRO_STATUS_SUCCESS: 
    error "cairo failed: " & $cairo.status_to_string(status)




## This function pushes a custom event onto the SDL event queue.
##  Whenever the main loop receives it, the window will be redrawn.
##  We can't redraw the window here, since this function could be called
##  from another thread.
## 
#proc timer_cb*(interval: Uint32; param: pointer): Uint32 = 
#  var event: SDL2.TEvent
#  event.kind = SDL2.USEREVENT
#  let rslt = SDL2.PushEvent(addr(event))
#  if rslt != 1: error "pushevent"
#  return interval



when isMainModule:
  if (SDL2.Init(SDL2.INIT_EVERYTHING) != SDL2.SdlSuccess):
    raise newException(EInvalidLibrary, "SDL Init Failed")

  const 
    width  = 480
    height = 480

  # lookup the enum code for 32bpp ARGB layout
  let ARGB8888: uint32 =
    SDL2.MasksToPixelFormatEnum(cint 32, 0x00FF0000,
                                         0x0000FF00,
                                         0x000000FF,
                                         0xFF000000) 

  var 
    window : SDL2.PWindow    # the app main window
    render : SDL2.PRenderer  # the renderer for it
    surface: SDL2.PSurface   # a window-sized buffer for pixels in RAM; cairo draws on this
    texture: SDL2.PTexture   # pixels on GPU, the framebuffer

  window = SDL2.CreateWindow("Cairo/SDL Clock", 
                             100, 100, cint width, cint height, 
                             SDL2.SDL_WINDOW_SHOWN)
  if window == nil: error "no window"

  render = SDL2.CreateRenderer(window, -1, SDL2.Renderer_Accelerated  or 
                                           SDL2.Renderer_PresentVsync or
                                           SDL2.Renderer_TargetTexture)
  if render == nil: error "no render"

  surface = mkSDLSurface(width, height)  
  if surface == nil: error "no surface"

  texture = SDL2.CreateTexture(render, ARGB8888,
                               cint SDL2.SDL_TEXTUREACCESS_STREAMING,
                               cint width, cint height)
  if texture == nil: error "no texture"

  var
    evt: SDL2.TEvent
    running = true

  while running:
    while SDL2.PollEvent(evt) != SDL2.Bool32(0):
      if evt.kind == SDL2.QuitEvent:
        running = false
        break
    
    # draw to pixels in RAM...
    draw_screen(surface)

    # copy pixels to GPU...
    #var clip: TRect = rect(0,0,width,height)
    SDL2.UpdateTexture(texture, nil, surface.pixels, cint(width*sizeof(uint32)))

    # GPU updates the screen: clear it, then copy from texture, then present
    SDL2.Clear(render)
    SDL2.Copy(render, texture, nil, nil)
    SDL2.Present(render)

    SDL2.Delay(10)

  finally:
    SDL2.destroy texture
    SDL2.destroy surface
    SDL2.destroy render
    SDL2.destroy window
    SDL2.Quit()
