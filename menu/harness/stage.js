// stage.js — deterministic replacement for the prototype's animations-v2 runtime.
// Provides the 9 window globals armapunk.jsx destructures, driven by an external
// seek API instead of requestAnimationFrame. Load before the design source.
(function () {
  const TL = React.createContext({ time: 0 });
  const SC = React.createContext({ localTime: 0, progress: 0, dur: 1 });

  window.useTimeline = () => React.useContext(TL);
  window.useScene = () => React.useContext(SC);
  window.useTweaks = (defaults) => [defaults, () => {}];
  const Null = () => null;
  window.TweaksPanel = Null;
  window.TweakSection = Null;
  window.TweakSlider = Null;
  window.TweakToggle = Null;
  window.TweakColor = Null;
  window.TweakRadio = Null;

  window.SceneStage = function SceneStage(props) {
    const [st, setSt] = React.useState({ t: 0 });
    // __seek resolves after two RAFs so the committed frame is on screen.
    window.__seek = (t) =>
      new Promise((res) => {
        window.__seekResolve = res;
        setSt({ t });
      });
    React.useEffect(() => {
      if (window.__seekResolve) {
        const r = window.__seekResolve;
        window.__seekResolve = null;
        requestAnimationFrame(() => requestAnimationFrame(() => r(st.t)));
      }
    }, [st]);

    const scenes = typeof props.scenes === 'string' ? JSON.parse(props.scenes) : props.scenes;
    const total = scenes.reduce((a, s) => a + s.dur, 0);
    const t = st.t;
    let body;
    if (window.__custom) {
      body = React.createElement(window.__custom, { t });
    } else {
      let tt = ((t % total) + total) % total,
        acc = 0,
        scene = scenes[0],
        lt = tt;
      for (const s of scenes) {
        if (tt < acc + s.dur) {
          scene = s;
          lt = tt - acc;
          break;
        }
        acc += s.dur;
      }
      const C = props.children[scene.name];
      body = React.createElement(
        SC.Provider,
        { value: { localTime: lt, progress: lt / scene.dur, dur: scene.dur } },
        React.createElement(C)
      );
    }
    return React.createElement(
      TL.Provider,
      { value: { time: t } },
      React.createElement(
        'div',
        {
          id: 'stage',
          style: {
            position: 'relative',
            width: props.width,
            height: props.height,
            background: window.__transparent ? 'transparent' : props.bg,
            overflow: 'hidden',
          },
        },
        body
      )
    );
  };
})();
