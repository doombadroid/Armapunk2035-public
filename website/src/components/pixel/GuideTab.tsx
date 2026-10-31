"use client";

import {
  AlertTriangle,
  ArrowRight,
  Banknote,
  Clock,
  FlaskConical,
  Gavel,
  Gift,
  Hammer,
  Lock,
  Pickaxe,
  Scale,
  Shield,
  ShoppingBasket,
  Siren,
  Sparkles,
  Star,
  TrendingUp,
  Truck,
  Users,
  Zap,
} from "lucide-react";
import { fmtMoney } from "./format";
import { Panel } from "./primitives";
import type { Statics } from "./types";

// Reference tk: a numbered "Getting started" step.
function Step({ n, title, children }: { n: number; title: string; children?: React.ReactNode }) {
  return (
    <li className="flex gap-3">
      <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-primary text-[11px] font-bold text-primary-foreground">{n}</span>
      <div className="min-w-0 flex-1 pt-0.5">
        <h4 className="text-xs font-semibold text-foreground">{title}</h4>
        <p className="mt-0.5 text-[11px] leading-relaxed text-muted-foreground">{children}</p>
      </div>
    </li>
  );
}

// Reference tw: an icon + term + explanation card.
function Term({ icon, term, children }: { icon: React.ReactNode; term: string; children?: React.ReactNode }) {
  return (
    <div className="flex gap-2.5 rounded-lg border border-border bg-surface p-2.5">
      <span className="mt-0.5 shrink-0 text-muted-foreground">{icon}</span>
      <div className="min-w-0">
        <div className="text-xs font-semibold text-foreground">{term}</div>
        <p className="mt-0.5 text-[11px] leading-relaxed text-muted-foreground">{children}</p>
      </div>
    </div>
  );
}

// Reference tN: the Guide tab.
export function GuideTab({ statics, wantedAt, isCop }: { statics: Statics; wantedAt: number; isCop: boolean }) {
  const r = statics.licenses.find((e) => "farming" === e.id);
  return (
    <div className="space-y-3">
      <Panel title="The short version" icon={<ArrowRight className="h-3.5 w-3.5 text-primary-emphasis" />}>
        <p className="text-xs leading-relaxed text-foreground-secondary">
          {
            "Altis, as a clicker. You click a job site to produce goods, run them through a processor to multiply their value, then haul them to a market and sell. Everything you earn buys skills, licences and a bigger vehicle, which lets you produce more per click and carry more per trip. Every price, weight and production chain is copied from the live server's own mission files."
          }
        </p>
      </Panel>
      <Panel title="Getting started" icon={<Pickaxe className="h-3.5 w-3.5 text-muted-foreground" />}>
        <ol className="space-y-3">
          <Step n={1} title="Pick a career">
            Civilians produce and sell, and are the only ones who can touch the illegal economy. APD officers earn a salary and take a cut of what they seize. You can change
            later — see Switching careers below.
          </Step>
          <Step n={2} title="Work the orchard">
            Apple and Peach need no licence and no level. They pay very little, which is the point: about twenty clicks gets you to level 2.
          </Step>
          <Step n={3} title="Buy the Farming Licence">
            {r ? fmtMoney(r.cost) : "$4,000"}
            {" on the Upgrades tab. It unlocks Cotton, which is where the money actually starts."}
          </Step>
          <Step n={4} title="Learn the chain">
            Cotton Field gives Raw Cotton ($350). Run it through the Cotton Gin and it becomes Cotton ($475) for the same weight. Processing is almost always worth the extra
            clicks — that is the core of the game.
          </Step>
          <Step n={5} title="Watch your load">
            You start with a 45kg backpack. When it fills you cannot gather, so sell or upgrade. Every item has the weight it has in the real mission, which is why Tuna is
            painful and Iron Ingots are not.
          </Step>
        </ol>
      </Panel>
      <div className="grid gap-3 lg:grid-cols-2">
        <Panel title="Core systems" icon={<TrendingUp className="h-3.5 w-3.5 text-muted-foreground" />} bodyClassName="p-3 space-y-2">
          <Term icon={<Pickaxe className="h-3.5 w-3.5" />} term="Gathering vs processing">
            A site marked with a pickaxe produces raw goods from nothing but stamina. A flask site converts what you are already carrying into something worth more.
            Processors need input in your bag.
          </Term>
          <Term icon={<Clock className="h-3.5 w-3.5" />} term="Stamina">
            Every click costs it, and it refills on its own whether or not the page is open. Endurance raises the ceiling and the refill rate.
          </Term>
          <Term icon={<Truck className="h-3.5 w-3.5" />} term="Capacity">
            Your vehicle sets how much weight you can carry; Strength adds a percentage on top. Bigger vehicles mean fewer trips to market.
          </Term>
          <Term icon={<ShoppingBasket className="h-3.5 w-3.5" />} term="The market is shared">
            {
              "Prices are global. Every sale pushes that item's price down for everyone, and it drifts back up over the following minutes. Cities also have their own demand multiplier, so where you sell matters."
            }
          </Term>
          <Term icon={<Users className="h-3.5 w-3.5" />} term="Work crews">
            Hire a crew at any gathering site and it keeps producing into your bag while you are elsewhere — or logged out entirely. Up to{" "}
            {statics.maxCrewsPerSite}
            {
              "per site, each costing more than the last. A crew's price tracks what it actually digs up, so every crew on the island pays for itself over roughly the same stretch of wall clock. Crews stop while you are an officer and resume if you go back."
            }
          </Term>
          <Term icon={<Banknote className="h-3.5 w-3.5" />} term="Travel">
            The five towns have different job sites and different demand. Travel time comes from the real distance between them on the Altis map, so crossing the island costs
            you more than hopping next door.
          </Term>
        </Panel>
        <Panel title="Levels, talents and tools" icon={<Sparkles className="h-3.5 w-3.5 text-muted-foreground" />} bodyClassName="p-3 space-y-2">
          <Term icon={<Star className="h-3.5 w-3.5" />} term="XP comes from everything">
            {
              "Every click, sale, arrest, patrol, licence, upgrade and crew you hire pays XP — and your crews keep earning it while you are away, at a third of the rate your own hands do. There are "
            }
            {statics.maxLevel}
            {" levels."}
          </Term>
          <Term icon={<Sparkles className="h-3.5 w-3.5" />} term="Talents">
            {"Each level grants "}
            {statics.talentPointsPerLevel}
            {
              " talent point. Points cannot be bought with cash — levelling is the only source. Talents change a rule rather than a number: a chance to double a harvest, a process that sometimes consumes nothing, a jackpot that fires more often. Later ranks cost more points, so you will not max everything. A respec refunds the lot for cash, and gets pricier each time."
            }
          </Term>
          <Term icon={<Hammer className="h-3.5 w-3.5" />} term="Tools">
            A separate ladder from your vehicle: the vehicle decides how much you can carry, tools decide how much a click produces. Gathering and processing have their own
            ladders, so a full-chain operation has to fund both. Every tier needs a level as well as the money.
          </Term>
          <Term icon={<Zap className="h-3.5 w-3.5" />} term="Auto-sell">
            {"Unlocks at level "}
            {statics.autoSellUnlockLevel}. Flip it on in the Work tab and everything you gather sells the moment it lands, at the local live price — pressure and all. Jackpot
            finds stay in your bag.
          </Term>
          <Term icon={<Clock className="h-3.5 w-3.5" />} term="Contractors">
            {"Contractors are hired with "}
            <span className="font-semibold text-foreground">contract papers</span>, never cash —{" "}
            {statics.workerContracts.map((e) => `${e.minutes}m for ${e.papers}`).join(", ")}
            {". The short contract is the best value per minute; the longer windows cost a premium for holding one of your "}
            {statics.workerMaxActive}
            {" slots without a re-hire. They work at ~"}
            {statics.workerRateMult}
            {"x a crew's rate on wall-clock time whether you are online or not, and"}
            {" "}
            <span className="font-semibold text-foreground">sell everything on the spot</span>
            {
              "at the site's local price — nothing to haul, nothing to spoil. That is a switch of its own in the Market tab: turn it off and contractors stock your bag like a crew instead, without touching what your own work clicks do. Papers drop as you work and ride inside the rarer chests. Sites that produce raw feedstock have nothing to sell, so they take a crew instead."
            }
          </Term>
          <Term icon={<FlaskConical className="h-3.5 w-3.5" />} term="Processing contracts">
            The upgraded contract, and the only one that will work a{" "}
            <span className="font-semibold text-foreground">processor</span>. Draw one up from{" "}
            {statics.processContractPaperCost}
            {" contract papers in the Inventory tab — they never drop and cannot be bought — then spend"}
            {" "}
            {statics.processContracts.map((e) => `${e.contracts} for ${e.minutes}m`).join(", ")}. A processor converts the feedstock{" "}
            <span className="font-semibold text-foreground">already in your bag</span>
            {
              " and sells the result, so it cashes in the half of the chain a plain contract cannot reach. Leave it without input and it simply idles — you are paying for the window, not the throughput."
            }
          </Term>
          <Term icon={<Gift className="h-3.5 w-3.5" />} term="Chests">
            Every work click and paid patrol can turn one up, from Weathered to Cartel Vault. Open them in the Inventory tab — the payout scales with your level, so a hoarded
            chest grows with you.
          </Term>
          <Term icon={<Users className="h-3.5 w-3.5" />} term="Gangs">
            Found one for ${statics.gang.createCost.toLocaleString()}
            {" at level"}
            {" "}
            {statics.gang.minLevel}
            {"+, or join from the directory. Half of every member's XP feeds the gang; each gang level gives everyone +1% yield and +1% XP and every second level adds a member slot —"}
            {" "}
            {statics.gang.baseCap}
            {" at the start, "}
            {statics.gang.maxCap}
            {
              " at the cap. A leader can set the gang private: it stays listed, but joining then needs an invite code that every member can read off the Gang tab. That code rolls every"
            }
            {" "}
            {Math.round(statics.gang.inviteWindowMs / 6e4)}
            {" minutes, and again the moment somebody joins with it."}
          </Term>
          <Term icon={<Star className="h-3.5 w-3.5" />} term="Prestige">
            {"At level "}
            {statics.maxLevel}, with every upgrade for your career bought and ${statics.prestige.cashBase.toLocaleString()}
            {
              "in hand, retire the run for a star. The active career and its bag return to square one on the next tier; the other career's progression, bag and equipment are untouched. Civilian prestige also restarts its crews. Each star buys one permanent perk rank for the career that earned it. The fee rises with each star held."
            }
          </Term>
          <Term icon={<Lock className="h-3.5 w-3.5" />} term="Locked sites">
            The best sites are level-gated, and the gates run the whole way up — the uranium chain does not open until level 21 and the reactor until 24. A locked card shows
            the level it wants.
          </Term>
        </Panel>
        <div className="space-y-3">
          <Panel title="The illegal economy" icon={<AlertTriangle className="h-3.5 w-3.5 text-red-600 dark:text-red-400" />} className="border-red-500/30" bodyClassName="p-3 space-y-2">
            <Term icon={<FlaskConical className="h-3.5 w-3.5" />} term="It pays far better">
              {"Crystal Meth sells for $2,500 a unit against Cotton's $475. Underground sites are the fast route to real money."}
            </Term>
            <Term icon={<AlertTriangle className="h-3.5 w-3.5" />} term="Heat">
              Gathering, processing and selling illegal goods all build heat. It cools on its own over time, and Stealth cools it faster.
            </Term>
            <Term icon={<Siren className="h-3.5 w-3.5" />} term={`Wanted at ${wantedAt}+ heat`}>
              Past that, officers in your city can see you and come after you. Below it, no officer can touch you — that floor is absolute.
            </Term>
            <Term icon={<Gavel className="h-3.5 w-3.5" />} term="Getting arrested">
              You lose every illegal item you are carrying and go into holding. From there it is your call: pay the fine to walk immediately, wait it out for free, or post bail
              any time in between — bail starts above the fine and gets cheaper the longer you have already served. Ditching contraband before they reach you halves your
              heat and avoids the arrest entirely.
            </Term>
            <Term icon={<Scale className="h-3.5 w-3.5" />} term="Paying off your record">
              On the Market tab, for cash — clears your wanted level outright and keeps everything in your bag. The price is your heat plus a share of the contraband you are
              carrying, since that is what an arrest would have taken, so it is dearest exactly when it is worth most. Waiting is always free; this is the fast way. Not
              available once you are in custody — that is what bail is for.
            </Term>
          </Panel>
          <Panel title="Playing as APD" icon={<Shield className="h-3.5 w-3.5 text-blue-600 dark:text-blue-400" />} className="border-blue-500/30" bodyClassName="p-3 space-y-2">
            <Term icon={<Banknote className="h-3.5 w-3.5" />} term="Salary">
              Pays every minute, online or not. It is your floor — you never earn nothing.
            </Term>
            <Term icon={<Siren className="h-3.5 w-3.5" />} term="Patrol">
              Your main click. If a player in your city is carrying heat it flags them for arrest. If nobody is, you work street crime instead, so a quiet server still pays.
            </Term>
            <Term icon={<Gavel className="h-3.5 w-3.5" />} term="Arrests">
              You keep a share of everything you seize plus part of their fine, but the payout falls as their heat cools and one arrest can never pay more than $
              {statics.maxArrestBounty.toLocaleString()}
              {" total. Backup officers split that same capped bounty. Arrests can fail and the target can get away."}
            </Term>
            <Term icon={<TrendingUp className="h-3.5 w-3.5" />} term="Your upgrade tree">
              Equipment (Patrol Car up to the Tactical Response Unit) raises arrest odds, bounty and cuts patrol cost. Certifications gate the higher tiers. Forensics raises
              your cut of seizures, Interrogation the fine, Dispatch the street-crime payout.
            </Term>
            <Term icon={<Pickaxe className="h-3.5 w-3.5" />} term="Off-duty work">
              Officers may work legal sites at half rate, using only the starter tool, backpack and vehicle while their civilian equipment sleeps. No illegal sites, auto-sell
              or crews.
            </Term>
          </Panel>
        </div>
      </div>
      <Panel title="Switching careers" icon={<Shield className="h-3.5 w-3.5 text-muted-foreground" />}>
        <p className="text-xs leading-relaxed text-foreground-secondary">
          You can change side from the Upgrades tab. Your current career is saved and the other one is restored exactly where you left it. Each side has its own cash, level,
          licences, respec cost, prestige tier and star perks, so APD bounty money cannot bankroll a civilian operation. Civilian vehicles, tools and crews and APD equipment
          also wait for their own side.
        </p>
        <p className="mt-2 text-xs leading-relaxed text-foreground-secondary">
          <strong>The two careers are separate builds.</strong>
          {
            "Skills and talents are held per career too, including shared-looking choices such as Endurance. Chests, contract papers and lifetime stats remain with the player. Each career has its own bag too, so goods cannot be sold into the other side's wallet. Civilian tools, backpack, vehicle, auto-sell and crews sleep on APD duty. There is a"
          }
          {" "}
          {statics.careerSwitchCooldownMin}-minute cooldown between changes, and you cannot join the APD while carrying heat; otherwise a switch would be a free record wipe
          during a chase.
        </p>
        <p className="mt-2 text-xs leading-relaxed text-foreground-secondary">
          {"Contraband in your bag does "}
          <strong>not</strong>
          {
            " stop you enlisting — your crews keep working while you empty it, so that rule only had you racing your own workers. Your entire civilian bag is stored intact and restored when you go civilian again; APD duty uses its own bag."
          }
        </p>
      </Panel>
      <Panel title="Worth knowing" icon={<ArrowRight className="h-3.5 w-3.5 text-muted-foreground" />}>
        <ul className="space-y-1.5 text-[11px] leading-relaxed text-muted-foreground">
          <li>· Progress accrues while you are away — stamina, heat, crews and salary all catch up when you return.</li>
          <li>· A site marked with a star has a rare bonus drop. Goldpan and the Gem Cutter are where the big ones are.</li>
          <li>· Some raw goods cannot be sold at all and exist only as processor input. The market tab shows a dash for those.</li>
          <li>{'· "FLOODED" on the market board means someone has been dumping that item and the price has not recovered yet.'}</li>
          {isCop && <li>· As an officer you can only see and arrest suspects in the city you are standing in. Travel to where the money is.</li>}
        </ul>
      </Panel>
    </div>
  );
}
