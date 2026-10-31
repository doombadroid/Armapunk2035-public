"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { parseAsStringLiteral, useQueryState } from "nuqs";
import { ArrowRight, BookOpen, Dices, Gamepad2, Loader2, Maximize2, MessageSquare, Minimize2, ShoppingBasket, Siren, TrendingUp, Users, Wrench } from "lucide-react";
import { cn } from "@/lib/utils";
import { CareerPick } from "./CareerPick";
import { CasinoTab } from "./CasinoTab";
import { ChatPanel } from "./ChatPanel";
import { CheckpointDialog } from "./CheckpointDialog";
import { CityGrid } from "./CityGrid";
import { GangTab } from "./GangTab";
import { GuideTab } from "./GuideTab";
import { InventoryTab } from "./InventoryTab";
import { IslandRail } from "./IslandRail";
import { MarketTab, type MarketView } from "./MarketTab";
import { MobileTabBar } from "./MobileTabBar";
import { PatrolTab } from "./PatrolTab";
import { PlayerCard } from "./PlayerCard";
import { PrisonWorkshop } from "./PrisonWorkshop";
import { PursuitDialog } from "./PursuitDialog";
import { StreetScene } from "./StreetScene";
import { TalentsTab } from "./TalentsTab";
import { Sheet, SheetContent, SheetHeader, SheetTitle } from "./ui/sheet";
import { UpgradesTab } from "./UpgradesTab";
import { usePixelClient } from "./usePixelClient";
import { WorkTab } from "./WorkTab";
import type { PopTone, Statics, TabDef, TabId } from "./types";

// Reference tq: the nuqs tab vocabulary.
const TAB_IDS = ["work", "casino", "market", "inventory", "progression", "upgrades", "talents", "gang", "clan", "police", "guide"] as const;

// Reference tV: pop colours.
const POP_TONES: Record<PopTone, string> = {
  gain: "text-green-400",
  cash: "text-green-400",
  heat: "text-red-400",
  bad: "text-red-400",
  gold: "text-amber-300",
  xp: "text-sky-300",
};

// Reference AsylumPixelPage: the page.
export default function PixelGame({ statics: e, canAccessCasino: p }: { statics: Statics; canAccessCasino: boolean }) {
  const v = useMemo(() => Object.fromEntries(e.items.map((e) => [e.id, e])), [e.items]);
  const w = useMemo(() => Object.fromEntries(e.sites.map((e) => [e.id, e])), [e.sites]);
  const N = useMemo(() => Object.fromEntries(e.licenses.map((e) => [e.id, e])), [e.licenses]);
  const C = useMemo(() => Object.fromEntries(e.cities.map((e) => [e.id, e])), [e.cities]);
  const P = useMemo(() => {
    const t: Record<string, { legal: number; illegal: number }> = {};
    for (const a of e.cities)
      t[a.id] = {
        legal: 0,
        illegal: 0,
      };
    for (const a of e.sites) {
      if (a.legal) t[a.cityId].legal += 1;
      else t[a.cityId].illegal += 1;
    }
    return t;
  }, [e]);
  const S = useMemo(() => {
    const t: Record<string, string> = {};
    for (const a of e.sites) {
      if ("process" !== a.mode || !a.input) continue;
      const e = `${a.name}, ${C[a.cityId]?.name ?? a.cityId}`;
      t[a.input] = t[a.input] ? `${t[a.input]} / ${e}` : e;
    }
    return t;
  }, [e.sites, C]);
  const L = useMemo(() => {
    const t: Record<string, Set<string>> = {};
    for (const a of e.sites) {
      (t[a.output] ??= new Set()).add(C[a.cityId]?.name ?? a.cityId);
      if (a.jackpot) (t[a.jackpot[0]] ??= new Set()).add(C[a.cityId]?.name ?? a.cityId);
    }
    return Object.fromEntries(Object.entries(t).map(([e, t]) => [e, [...t].join(" · ")]));
  }, [e.sites, C]);
  const M = useMemo(() => {
    const t = [...e.cities].sort((e, t) => t.demand - e.demand)[0];
    return t
      ? {
          name: t.name,
          demand: t.demand,
        }
      : null;
  }, [e.cities]);
  const {
    snap: A,
    loading: I,
    error: $,
    clock: T,
    pops: D,
    busy: R,
    act: F,
    chatPending: E,
    chatDraft: O,
    setChatDraft: B,
    chatError: U,
    sendChat: _,
    chatUnread: G,
    markChatRead: H,
    chatSentVersion: W,
    connection: z,
    lastUpdated: q,
  } = usePixelClient(useCallback((e: string) => v[e]?.name ?? e, [v]));
  const [K, X] = useQueryState("tab", parseAsStringLiteral(TAB_IDS).withDefault("work"));
  const [J, Q] = useState<MarketView>("sell");
  const [Z, ee] = useState<string | null>(null);
  const [et, ea] = useState(false);
  const [er, en] = useState(false);
  useEffect(() => {
    try {
      // eslint-disable-next-line react-hooks/set-state-in-effect -- reference: restores the saved fullscreen preference on mount
      if ("1" === localStorage.getItem("apFocus")) en(true);
    } catch {}
  }, []);
  const ei = useCallback(() => {
    en((e) => {
      const t = !e;
      try {
        localStorage.setItem("apFocus", t ? "1" : "0");
      } catch {}
      return t ? document.documentElement.requestFullscreen?.().catch(() => {}) : document.fullscreenElement && document.exitFullscreen?.().catch(() => {}), t;
    });
  }, []);
  useEffect(() => {
    if (!er) return;
    const e = (e: KeyboardEvent) => {
      if ("Escape" === e.key && !document.querySelector('[role="alertdialog"]')) {
        en(false);
        try {
          localStorage.setItem("apFocus", "0");
        } catch {}
      }
    };
    return window.addEventListener("keydown", e), () => window.removeEventListener("keydown", e);
  }, [er]);
  const el = A?.me ?? null;
  const eo = el ? C[el.cityId] : undefined;
  const ed = !!el && el.activityLockUntil > T;
  const em = !!el && (el.jailedUntil > T || el.travelUntil > T || ed);
  const ex = el?.faction === "cop";
  const eu = useRef<HTMLDivElement>(null);
  const [eh, ep] = useState(0);
  useEffect(() => {
    const e = eu.current;
    if (!e || "u" < typeof ResizeObserver) return;
    const t = new ResizeObserver(([e]) => ep(Math.round(e.contentRect.height)));
    return t.observe(e), () => t.disconnect();
  }, [el?.faction, er]);
  const eg = 56 * Number(!er);
  const ef = useMemo(() => (el ? e.sites.filter((e) => e.cityId === el.cityId) : []), [e.sites, el]);
  const eb = useMemo(() => (el && A ? A.roster.filter((e) => e.cityId === el.cityId) : []), [A, el]);
  const ey = useMemo(() => {
    if (!el) return 0;
    let e = 0;
    for (const [t, a] of Object.entries(el.inventory)) if (a > 0 && v[t] && !v[t].legal) e += a;
    return e;
  }, [el, v]),
  ej: TabId =
    "clan" === K
      ? ex
        ? "work"
        : "gang"
      : "police" !== K || ex
        ? "gang" === K && ex
          ? "work"
          : "casino" !== K || p
            ? "inventory" === K
              ? "market"
              : "upgrades" === K || "talents" === K
                ? "progression"
                : K
            : "work"
        : "work";
  const ek = "talents" === K ? "talents" : "upgrades";
  const ew = useCallback(
    (e: TabId) => {
      if ("inventory" === e) {
        Q("inventory");
        X("market");
      } else if ("progression" === e) X("upgrades");
      else X(e);
      if (("market" === e || "inventory" === e) && "market" === e) Q("sell");
    },
    [X],
  );
  const eN = useMemo(() => {
    if (!el || !el.faction) return [];
    const t: { text: string; tab: TabId }[] = [],
      a = Object.values(el.chests).reduce((e, t) => e + (t || 0), 0);
    if (el.starPicks > 0)
      t.push({
        text: "You have a star to spend — pick a permanent perk",
        tab: "upgrades",
      });
    if (el.prestigeReady)
      t.push({
        text: "Prestige is ready — retire this run for a star",
        tab: "upgrades",
      });
    if (el.capacity > 0 && el.carried / el.capacity >= 0.85 && !el.autoSell)
      t.push({
        text: "Bag nearly full — sell your haul",
        tab: "market",
      });
    if (el.talentPoints > 0)
      t.push({
        text: `${el.talentPoints} talent point${1 === el.talentPoints ? "" : "s"} to spend`,
        tab: "talents",
      });
    if (a > 0)
      t.push({
        text: `${a} unopened chest${1 === a ? "" : "s"}`,
        tab: "inventory",
      });
    if ("civ" === el.faction && el.papers >= (e.workerContracts[0]?.papers ?? 1 / 0) && el.workers.length < e.workerMaxActive)
      t.push({
        text: `${el.papers} contract paper${1 === el.papers ? "" : "s"} — put a contractor to work`,
        tab: "work",
      });
    if (!el.autoSell && el.level >= e.autoSellUnlockLevel && "civ" === el.faction)
      t.push({
        text: "Auto-sell is unlocked — flip it on",
        tab: "market",
      });
    if ("civ" === el.faction) {
      const a = e.tools.filter((e) => "gather" === e.kind).find((e) => e.tier === el.tools.gather + 1),
        s = e.backpacks[el.packTier + 1],
        r = e.gear[el.gearTier + 1],
        n = [
          a && el.level >= a.minLevel && el.cash >= a.cost ? a.name : null,
          s && el.level >= s.minLevel && el.cash >= s.cost ? s.name : null,
          r && el.cash >= r.cost ? r.name : null,
        ].filter(Boolean);
      if (n.length)
        t.push({
          text: `You can afford the ${n[0]}`,
          tab: "upgrades",
        });
    }
    return t.slice(0, 2);
  }, [el, e]);
  const eC: TabDef[] = [
    {
      id: "work",
      label: "Work",
      icon: <Wrench className="h-3.5 w-3.5" />,
      show: true,
    },
    {
      id: "police",
      label: "Patrol",
      icon: <Siren className="h-3.5 w-3.5" />,
      show: !!ex,
    },
    {
      id: "casino",
      label: "Casino",
      icon: <Dices className="h-3.5 w-3.5" />,
      show: p,
    },
    {
      id: "market",
      label: "Market",
      icon: <ShoppingBasket className="h-3.5 w-3.5" />,
      show: true,
    },
    {
      id: "progression",
      label: el && el.talentPoints > 0 ? `Progression (${el.talentPoints})` : "Progression",
      icon: <TrendingUp className="h-3.5 w-3.5" />,
      show: true,
    },
    {
      id: "gang",
      label: "Gang",
      icon: <Users className="h-3.5 w-3.5" />,
      show: !ex,
    },
    {
      id: "guide",
      label: "Guide",
      icon: <BookOpen className="h-3.5 w-3.5" />,
      show: true,
    },
  ];
  return (
    <>
      <section className={cn(er ? "fixed inset-0 z-[80] overflow-y-auto overscroll-contain bg-background px-3 py-3" : "px-4 pb-20 pt-8 lg:pb-8")}>
        <div className={cn("mx-auto", er ? "max-w-none" : "max-w-screen-2xl")}>
          <header className={cn("flex items-center gap-2.5", er ? "mb-3" : "mb-4")}>
            <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-primary/15">
              <Gamepad2 className="h-5 w-5 text-primary-emphasis" />
            </div>
            <div className="">
              <h1 className="text-xl font-bold text-foreground">Armapunk Pixel</h1>
              {!er && (
                <p className="text-xs text-muted-foreground">
                  Enjoy Asylum Redux in a pixelated realm as an idle/clicker game. This is purely for entertainment purposes when you are not in the Altis world. Your progress
                  here does not affect your real Altis stats or inventory.
                </p>
              )}
            </div>
            <div className="ml-auto flex items-center gap-2">
              {A && (
                <span className="inline-flex items-center gap-1.5 rounded-full border border-border bg-card px-2.5 py-1 text-[10px] text-muted-foreground">
                  <span className="h-1.5 w-1.5 rounded-full bg-green-500" />
                  {A.online}
                  {" online"}
                </span>
              )}
              <button
                type="button"
                onClick={ei}
                title={er ? "Exit fullscreen (Esc)" : "Fullscreen"}
                className="inline-flex items-center gap-1.5 rounded-md border border-border bg-card px-2.5 py-1.5 text-[10px] font-semibold text-muted-foreground transition hover:bg-muted hover:text-foreground"
              >
                {er ? <Minimize2 className="h-3.5 w-3.5" /> : <Maximize2 className="h-3.5 w-3.5" />}
                {er ? "Exit" : "Fullscreen"}
              </button>
            </div>
          </header>
          {$ && <div className="mb-3 rounded-lg border border-red-500/40 bg-red-500/10 px-3 py-2 text-xs text-red-700 dark:text-red-300">{$}</div>}
          {I && !A ? (
            <div className="py-24 text-center">
              <Loader2 className="mx-auto mb-4 h-10 w-10 animate-spin text-primary-emphasis" />
              <p className="text-sm text-muted-foreground">Landing at Kavala…</p>
            </div>
          ) : A && el ? (
            el.faction ? (
              <div className="space-y-3">
                <div
                  ref={eu}
                  style={{
                    top: eg,
                  }}
                  className="sticky z-30"
                >
                  <PlayerCard me={el} city={eo} clock={T} wantedAt={el.visibleAt} itemMap={v} onRelease={() => F("release")} />
                </div>
                <CityGrid
                  cities={e.cities}
                  currentId={el.cityId}
                  travel={e.travel}
                  sitesPerCity={P}
                  heads={A?.headsByCity ?? {}}
                  disabled={R || em}
                  onTravel={(e) =>
                    F("travel", {
                      cityId: e,
                    })
                  }
                />
                {el.jailedUntil > T && (
                  <PrisonWorkshop
                    me={el}
                    clock={T}
                    disabled={R}
                    onStart={() => F("prisonstart")}
                    onRotate={(e) => {
                      const c = el.custody;
                      if (c?.job)
                        F("prisonrotate", {
                          custodyId: c.id,
                          jobId: c.job.id,
                          tile: e,
                        });
                    }}
                    onComplete={() => {
                      const c = el.custody;
                      if (c?.job)
                        F("prisoncomplete", {
                          custodyId: c.id,
                          jobId: c.job.id,
                        });
                    }}
                  />
                )}
                {!er && (
                  <StreetScene
                    cityName={eo?.name ?? ""}
                    players={eb}
                    meSteamId={el.steamId}
                    onSelect={
                      ex
                        ? (e) => {
                            if ("civ" === e.faction) ew("police");
                          }
                        : undefined
                    }
                  />
                )}
                <div className="flex h-[26px] flex-nowrap items-center gap-2 overflow-x-auto">
                  {eN.length > 0 && (
                    <>
                      <span className="shrink-0 text-[10px] font-semibold uppercase tracking-wide text-muted-foreground">What now?</span>
                      {eN.map((e) => (
                        <button
                          key={e.text}
                          type="button"
                          onClick={() => ew(e.tab)}
                          className="inline-flex shrink-0 items-center gap-1 rounded-full border border-primary/40 bg-primary/10 px-2.5 py-1 text-[10px] font-medium text-primary-emphasis transition hover:bg-primary/20"
                        >
                          {e.text}
                          <ArrowRight className="h-3 w-3" />
                        </button>
                      ))}
                    </>
                  )}
                </div>
                <div className="grid gap-3 xl:grid-cols-[minmax(0,1fr)_320px]">
                  <div className="min-w-0">
                    <div
                      style={{
                        top: eg + eh,
                      }}
                      className="sticky z-20 mb-3 -mx-1 hidden overflow-x-auto bg-background px-1 pt-3 lg:block"
                    >
                      <div className="flex gap-1 rounded-lg border border-border bg-card p-1 shadow-sm">
                        {eC.filter((e) => e.show).map((e) => (
                          <button
                            key={e.id}
                            type="button"
                            onClick={() => ew(e.id)}
                            className={cn(
                              "inline-flex flex-1 items-center justify-center gap-1.5 whitespace-nowrap rounded-md px-3 py-2",
                              "text-xs font-semibold transition",
                              ej === e.id ? "bg-primary text-primary-foreground" : "text-muted-foreground hover:bg-surface hover:text-foreground",
                            )}
                          >
                            {e.icon}
                            {e.label}
                          </button>
                        ))}
                      </div>
                    </div>
                    {"work" === ej && (
                      <WorkTab
                        sites={ef}
                        me={el}
                        statics={e}
                        itemMap={v}
                        licenseMap={N}
                        prices={A.prices}
                        busy={R}
                        disabled={R || em}
                        clock={T}
                        onWork={(e) =>
                          F("work", {
                            siteId: e,
                          })
                        }
                        onSell={(e) =>
                          F("sell", {
                            itemId: e,
                            amount: "all",
                          })
                        }
                        onHire={(e) =>
                          F("crew", {
                            siteId: e,
                          })
                        }
                        onWorker={(e, t, a) =>
                          F("worker", {
                            siteId: e,
                            minutes: t,
                            kind: a,
                          })
                        }
                      />
                    )}
                    {"police" === ej && ex && (
                      <PatrolTab
                        me={el}
                        city={eo}
                        suspects={A.suspects}
                        npcCrime={A.npcCrime[el.cityId] ?? 0}
                        dispatch={A.dispatch}
                        cityName={(e) => C[e]?.name ?? e}
                        clock={T}
                        disabled={R || em}
                        busy={R}
                        onCaseStart={(e) =>
                          F("casestart", {
                            practice: e,
                          })
                        }
                        onCaseAnswer={(e, t) =>
                          F("caseanswer", {
                            id: el.apdCase?.id ?? "",
                            round: e,
                            choice: t,
                          })
                        }
                        onBust={(e) =>
                          F("bust", {
                            targetId: e,
                          })
                        }
                      />
                    )}
                    {"market" === ej && (
                      <MarketTab
                        me={el}
                        city={eo}
                        items={e.items}
                        itemMap={v}
                        prices={A.prices}
                        mults={A.mults}
                        disabled={R || em}
                        processedAt={S}
                        sourcedAt={L}
                        bestCity={M}
                        statics={e}
                        view={"inventory" === K ? "inventory" : J}
                        onViewChange={(e) => {
                          Q(e);
                          X("market");
                        }}
                        inventory={
                          <InventoryTab
                            me={el}
                            statics={e}
                            itemMap={v}
                            siteMap={w}
                            prices={A.prices}
                            clock={T}
                            disabled={R || em}
                            onOpen={(e) =>
                              F("openchest", {
                                rarity: e,
                              })
                            }
                            onCraftContract={(e) =>
                              F("craftcontract", {
                                qty: e,
                              })
                            }
                          />
                        }
                        onSell={(e, t) =>
                          F("sell", {
                            itemId: e,
                            amount: t,
                          })
                        }
                        onDrop={(e, t) =>
                          F("drop", {
                            itemId: e,
                            amount: t,
                          })
                        }
                        onDitch={() => F("ditch")}
                        onPayHeat={() => F("payheat")}
                        onAutoSell={() => F("autosell")}
                        onWorkerAutoSell={() => F("workerautosell")}
                      />
                    )}
                    {p && "casino" === ej && A.casino && <CasinoTab me={el} casino={A.casino} disabled={R || em} onAction={F} />}
                    {"guide" === ej && <GuideTab statics={e} wantedAt={A.wantedAt} isCop={!!ex} />}
                    {"progression" === ej && (
                      <div className="space-y-3">
                        <div className="rounded-lg border border-border bg-card p-1.5">
                          <div role="tablist" aria-label="Progression sections" className="grid grid-cols-2 gap-1">
                            <button
                              type="button"
                              role="tab"
                              aria-selected={"upgrades" === ek}
                              onClick={() => X("upgrades")}
                              className={cn(
                                "flex min-h-12 flex-col items-center justify-center rounded-md px-3 py-2 text-xs font-bold transition",
                                "upgrades" === ek ? "bg-primary text-primary-foreground shadow-sm" : "text-muted-foreground hover:bg-surface hover:text-foreground",
                              )}
                            >
                              Upgrades<span className="text-[10px] font-medium opacity-75">Spend cash</span>
                            </button>
                            <button
                              type="button"
                              role="tab"
                              aria-selected={"talents" === ek}
                              onClick={() => X("talents")}
                              className={cn(
                                "flex min-h-12 flex-col items-center justify-center rounded-md px-3 py-2 text-xs font-bold transition",
                                "talents" === ek ? "bg-primary text-primary-foreground shadow-sm" : "text-muted-foreground hover:bg-surface hover:text-foreground",
                              )}
                            >
                              Talents
                              <span className="text-[10px] font-medium opacity-75">
                                {el.talentPoints > 0 ? `${el.talentPoints} point${1 === el.talentPoints ? "" : "s"} ready` : "Earn with levels"}
                              </span>
                            </button>
                          </div>
                        </div>
                        {"upgrades" === ek ? (
                          <UpgradesTab
                            me={el}
                            statics={e}
                            siteMap={w}
                            disabled={R || em}
                            clock={T}
                            contrabandUnits={ey}
                            onSkill={(e) =>
                              F("skill", {
                                skillId: e,
                              })
                            }
                            onLicense={(e) =>
                              F("license", {
                                licenseId: e,
                              })
                            }
                            onGear={() => F("gear")}
                            onCopGear={() => F("copgear")}
                            onSwitch={(e) =>
                              F("switch", {
                                faction: e,
                              })
                            }
                            onReset={() => F("reset")}
                            onTool={(e) =>
                              F("tool", {
                                kind: e,
                              })
                            }
                            onPack={() => F("pack")}
                            onPrestige={() => F("prestige")}
                            onStarPerk={(e) =>
                              F("starperk", {
                                perkId: e,
                              })
                            }
                            onCrewPause={(e, t) =>
                              F("crewpause", {
                                siteId: e,
                                paused: t,
                              })
                            }
                          />
                        ) : (
                          <TalentsTab
                            me={el}
                            statics={e}
                            disabled={R || em}
                            onLearn={(e) =>
                              F("talent", {
                                talentId: e,
                              })
                            }
                            onRespec={() => F("respec")}
                          />
                        )}
                      </div>
                    )}
                    {"gang" === ej && !ex && (
                      <GangTab
                        me={el}
                        gangs={A.gangs}
                        statics={e}
                        disabled={R || em}
                        onCreate={(e, t) =>
                          F("gangcreate", {
                            name: e,
                            tag: t,
                          })
                        }
                        onJoin={(e, t) =>
                          F("gangjoin", {
                            gangId: e,
                            code: t,
                          })
                        }
                        onLeave={() => F("gangleave")}
                        onKick={(e) =>
                          F("gangkick", {
                            targetId: e,
                          })
                        }
                        onPrivacy={(e) =>
                          F("gangprivacy", {
                            private: e,
                          })
                        }
                      />
                    )}
                  </div>
                  <div className="hidden min-w-0 flex-col gap-3 xl:flex">
                    <ChatPanel
                      messages={A.chat}
                      meSteamId={el.steamId}
                      clock={T}
                      maxLen={e.chatMaxLen}
                      chatPending={E}
                      draft={O}
                      onDraftChange={B}
                      onSend={_}
                      visible={true}
                      onRead={H}
                      sendError={U}
                      sentVersion={W}
                      connection={z}
                      lastUpdated={q}
                    />
                    <IslandRail snap={A} cityName={(e) => C[e]?.name ?? e} meSteamId={el.steamId} clock={T} />
                  </div>
                </div>
              </div>
            ) : (
              <CareerPick
                disabled={R}
                onPick={(e) =>
                  F("faction", {
                    faction: e,
                  })
                }
              />
            )
          ) : null}
        </div>
      </section>
      {el?.faction && A && (
        <>
          <MobileTabBar tabs={eC} activeTab={ej} onSelect={(e) => ew(e)} />
          <button
            type="button"
            onClick={() => ea(true)}
            aria-label="Open chat and activity feed"
            className={cn(
              "fixed bottom-20 right-4 z-40 flex h-12 w-12 items-center justify-center rounded-full",
              "bg-primary text-primary-foreground shadow-lg transition hover:brightness-110",
              "lg:bottom-6 xl:hidden",
            )}
          >
            <MessageSquare className="h-5 w-5" />
            {G > 0 && (
              <span className="absolute -right-1 -top-1 flex h-5 min-w-5 items-center justify-center rounded-full bg-destructive px-1 text-[10px] font-semibold text-destructive-foreground">
                {G > 99 ? "99+" : G}
              </span>
            )}
          </button>
          <Sheet open={et} onOpenChange={ea}>
            <SheetContent side="bottom" className="max-h-[85vh] overflow-y-auto xl:hidden">
              <SheetHeader>
                <SheetTitle>Chat &amp; Activity</SheetTitle>
              </SheetHeader>
              <div className="flex flex-col gap-3 p-4 pt-0">
                <ChatPanel
                  messages={A.chat}
                  meSteamId={el.steamId}
                  clock={T}
                  maxLen={e.chatMaxLen}
                  chatPending={E}
                  draft={O}
                  onDraftChange={B}
                  onSend={_}
                  visible={et}
                  onRead={H}
                  sendError={U}
                  sentVersion={W}
                  connection={z}
                  lastUpdated={q}
                />
                <IslandRail snap={A} cityName={(e) => C[e]?.name ?? e} meSteamId={el.steamId} clock={T} />
              </div>
            </SheetContent>
          </Sheet>
        </>
      )}
      <div className="pointer-events-none fixed bottom-24 right-3 z-[90] flex flex-col items-end gap-1.5 sm:right-6">
        {D.map((e) => (
          <span key={e.id} className={cn("ap-pop rounded-md bg-slate-900/80 px-2.5 py-1 font-mono text-xs font-semibold shadow-lg backdrop-blur-sm", POP_TONES[e.tone] ?? "text-green-400")}>
            {e.text}
          </span>
        ))}
      </div>
      {el?.checkpoint ? (
        <CheckpointDialog
          checkpoint={el.checkpoint}
          clock={T}
          disabled={R}
          error={Z}
          onAnswer={async (e, t) => {
            const a = await F("verify", {
              id: e,
              answer: t,
            });
            ee(a && !a.ok ? (a.error ?? null) : null);
          }}
        />
      ) : el?.duel ? (
        <PursuitDialog
          duel={el.duel}
          clock={T}
          disabled={R}
          onReady={() =>
            F("pursuitready", {
              id: el.duel?.id ?? "",
            })
          }
          onAnswer={(e, t) =>
            F("pursuitanswer", {
              id: el.duel?.id ?? "",
              round: e,
              choice: t,
            })
          }
          onSurrender={() =>
            F("pursuitsurrender", {
              id: el.duel?.id ?? "",
            })
          }
        />
      ) : null}
      {el && el.faction && (
        <button type="button" aria-hidden="true" tabIndex={-1} onClick={() => F("hp")} className="pointer-events-auto fixed -left-[9999px] top-0 h-px w-px overflow-hidden opacity-0">
          Claim free cash
        </button>
      )}
    </>
  );
}
