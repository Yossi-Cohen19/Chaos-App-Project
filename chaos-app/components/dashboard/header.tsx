"use client"

import { Cloud, GitBranch, Activity, Terminal } from "lucide-react"

export function DashboardHeader({
  environment = "AWS EKS (us-east-1)",
  version = "v2.4.0",
  commit = "8f2a1d"
}: {
  environment?: string
  version?: string
  commit?: string
}) {
  return (
    <header className="border-b border-primary/30 bg-card/90 backdrop-blur-sm shadow-[0_5px_30px_rgba(34,211,238,0.1)]">
      <div className="flex items-center justify-between px-6 py-3">
        {/* Logo / Title */}
        <div className="flex items-center gap-3">
          <div className="relative p-2 rounded-lg bg-primary/10 border border-primary/30 shadow-[0_0_15px_rgba(34,211,238,0.2)]">
            <Terminal className="h-5 w-5 text-primary neon-text" />
            <span className="absolute -top-1 -right-1 h-2.5 w-2.5 rounded-full bg-accent shadow-[0_0_8px_rgba(16,185,129,0.8)] animate-pulse" />
          </div>
          <div>
            <h1 className="text-sm font-semibold tracking-widest uppercase text-foreground font-sans">
              DevOps Resilience
            </h1>
            <p className="text-xs text-primary/60 font-mono tracking-wider">PLATFORM {version}</p>
          </div>
        </div>

        {/* Status Items */}
        <div className="flex items-center gap-6">
          {/* Environment */}
          <div className="flex items-center gap-2">
            <Cloud className="h-4 w-4 text-primary" />
            <span className="text-sm text-muted-foreground font-sans">Environment:</span>
            <span className="font-mono text-sm text-primary tracking-wider">{environment}</span>
          </div>

          {/* Build Version */}
          <div className="flex items-center gap-2">
            <Activity className="h-4 w-4 text-accent" />
            <span className="text-sm text-muted-foreground font-sans">Build:</span>
            <span className="font-mono text-sm px-2 py-0.5 rounded-md bg-accent/20 text-accent border border-accent/40 shadow-[0_0_15px_rgba(16,185,129,0.3)] tracking-wider">
              {version}
            </span>
          </div>

          {/* Commit */}
          <div className="flex items-center gap-2">
            <GitBranch className="h-4 w-4 text-primary" />
            <span className="text-sm text-muted-foreground font-sans">Commit:</span>
            <span className="font-mono text-sm text-primary neon-text tracking-wider">{commit}</span>
          </div>

          {/* Live Indicator */}
          <div className="flex items-center gap-2 pl-4 border-l border-primary/20">
            <span className="relative flex h-2.5 w-2.5">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-accent opacity-75" />
              <span className="relative inline-flex rounded-full h-2.5 w-2.5 bg-accent shadow-[0_0_10px_rgba(16,185,129,0.8)]" />
            </span>
            <span className="text-xs text-accent font-mono uppercase tracking-widest neon-text">Live</span>
          </div>
        </div>
      </div>
    </header>
  )
}
