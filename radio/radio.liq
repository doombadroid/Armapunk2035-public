# Malden Radio — liquidsoap station script (dev: docker; prod: systemd on .96)
settings.log.stdout := true

host = environment.get(default="127.0.0.1", "ICECAST_HOST")
pass = environment.get(default="devsource", "ICECAST_SOURCE_PASSWORD")
music = environment.get(default="/music", "RADIO_MUSIC_DIR")

def station(mount, name) =
  s = playlist(mode="randomize", reload_mode="watch", "#{music}/#{mount}")
  s = mksafe(s)   # empty/missing dir -> silence, never a crash
  output.icecast(%mp3(bitrate=128), host=host, port=8000, password=pass,
                 mount="/#{mount}", name=name, s)
end

station("origin", "Origin FM")
station("khr", "KHR")
station("pulse", "Pulse Electro")
station("classico", "Classico")
station("anarchy", "Anarchy Rock")
