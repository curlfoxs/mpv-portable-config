##Source: https://bbs.vcb-s.com/?14732
##@Starlight 的个人高参脚本，性能要求较高

import vapoursynth as vs
from vapoursynth import core

clip = video_in
w = video_in_dw
h = video_in_dh
freq = display_fps
fps = container_fps or 23.976
target_fps = 60


def fit(clip, w, h, vw=1920, vh=1080, s=lambda x, b=4: round(x)//b*b):
    if w > vw or h > vh:
        r = max(w/vw, h/vh)
        w, h = w/r, h/r
        clip = clip.resize.Spline36(width=s(w), height=s(h))
    return clip


def toYUV420(clip):
    if clip.format.id == vs.YUV420P8:
        clip8 = clip
    elif clip.format.id == vs.YUV420P10:
        clip8 = clip.resize.Point(format=vs.YUV420P8)
    else:
        clip = clip.resize.Point(format=vs.YUV420P10)
        clip8 = clip.resize.Point(format=vs.YUV420P8)
    return clip, clip8


def svpflow(clip, fps, target_fps):
    sp = "{ gpu: 1 }",
    ap = """{
        block: { w: 32, h: 16, overlap: 2 },
        main: {
            levels: 5,
            search: {
                type: 4, distance: -8,
                coarse: { type: 4, distance: -4, bad: { range: 0 } }
            },
            penalty: { lambda: 3.3, lsad: 3000, plevel: 1.25, pzero: 110, pnbour: 75 }
        },
        refine: [{ thsad: 200, search: { type: 4, distance: -2 } }]
    }""",
    fp = """{
        gpuid: 0,
        algo: 23, rate: { num: %d, den: %d, abs: true },
        scene: { mode: 0, limits: { scene: 5200, zero: 100 } },
        mask: { cover: 88, area: 100, area_sharp: 0.7 }
    }""" % (round(target_fps) * 1000, 1001)
    clip, clip8 = toYUV420(clip)
    s = core.svp1.Super(clip8, sp)
    r = s["clip"], s["data"]
    v = core.svp1.Analyse(*r, clip, ap)
    r = *r, v["clip"], v["data"]
    clip = core.svp2.SmoothFps(clip, *r, fp, src=clip, fps=fps)
    return clip


clip = fit(clip, w, h)
clip = svpflow(clip, fps, target_fps)
clip.set_output()
