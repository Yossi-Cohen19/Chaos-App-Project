"use client"

import { useState, useEffect, useRef } from "react"
import { Database, Skull, Server, RefreshCw } from "lucide-react"
import { Button } from "@/components/ui/button"

const POD_IDS = [
  "worker-node-xf92",
  "worker-node-ab14",
  "worker-node-ck77",
  "worker-node-dz31",
  "worker-node-ep55",
]

type LogEntry = {
  timestamp: string
  level: "INFO" | "WARN" | "ERROR" | "K8S"
  message: string
}

const NORMAL_LOGS = [
  "Health check passed - 200 OK",
  "Incoming request processed",
  "Cache hit for user session",
  "Database query completed in 12ms",
  "Connection pool: 8/20 active",
  "Memory usage: 342MB / 512MB",
  "Heartbeat sent to control plane",
  "Request latency: 23ms avg",
  "SSL certificate valid for 89 days",
  "Background job completed",
]

export function ResiliencePanel() {
  const [hitCount, setHitCount] = useState(42847)
  const [podId, setPodId] = useState(POD_IDS[0])
  const [isReconnecting, setIsReconnecting] = useState(false)
  const [podStatus, setPodStatus] = useState<"healthy" | "terminated" | "reconnecting">("healthy")
  const [isGlitching, setIsGlitching] = useState(false)
  const [logs, setLogs] = useState<LogEntry[]>([])
  const [isKillActive, setIsKillActive] = useState(false)
  const logContainerRef = useRef<HTMLDivElement>(null)

  const getTimestamp = () => {
    const now = new Date()
    return now.toTimeString().split(" ")[0]
  }

  const addLog = (level: LogEntry["level"], message: string) => {
    setLogs((prev) => [...prev.slice(-50), { timestamp: getTimestamp(), level, message }])
  }

  // Initialize logs
  useEffect(() => {
    const initialLogs: LogEntry[] = []
    for (let i = 0; i < 5; i++) {
      initialLogs.push({
        timestamp: getTimestamp(),
        level: "INFO",
        message: NORMAL_LOGS[Math.floor(Math.random() * NORMAL_LOGS.length)],
      })
    }
    setLogs(initialLogs)
  }, [])

  // Auto-scroll logs
  useEffect(() => {
    if (logContainerRef.current) {
      logContainerRef.current.scrollTop = logContainerRef.current.scrollHeight
    }
  }, [logs])

  // Normal log generation
  useEffect(() => {
    if (isReconnecting) return
    const interval = setInterval(() => {
      addLog("INFO", NORMAL_LOGS[Math.floor(Math.random() * NORMAL_LOGS.length)])
    }, 2000)
    return () => clearInterval(interval)
  }, [isReconnecting])

  // Simulate live counter
  useEffect(() => {
    const interval = setInterval(() => {
      if (!isReconnecting) {
        setHitCount((prev) => prev + Math.floor(Math.random() * 5) + 1)
      }
    }, 100)
    return () => clearInterval(interval)
  }, [isReconnecting])

  const handleKillPod = async () => {
    setIsReconnecting(true)
    setIsKillActive(true)
    setIsGlitching(true)
    setPodStatus("terminated")

    // Call backend to kill process
    try {
      fetch('/api/kill', { method: 'POST' }).catch(err => console.error("Kill request sent (expecting failure as server dies):", err));
    } catch (e) {
      // Ignore network errors as server dies
    }

    // Inject termination logs rapidly
    addLog("WARN", `SIGTERM received for ${podId}`)
    setTimeout(() => addLog("ERROR", "Process terminating..."), 200)
    setTimeout(() => addLog("K8S", "Pod marked for deletion"), 400)
    setTimeout(() => addLog("K8S", "Scaling up ReplicaSet..."), 600)
    setTimeout(() => addLog("WARN", "Draining connections..."), 800)
    setTimeout(() => addLog("K8S", "New pod scheduled on node-pool-2"), 1000)

    // Stop intense button pulse after 1s
    setTimeout(() => {
      setIsKillActive(false)
    }, 1000)

    // Transition to reconnecting
    setTimeout(() => {
      setPodStatus("reconnecting")
      addLog("K8S", "Waiting for pod readiness probe...")
    }, 1200)

    // Recovery
    setTimeout(() => {
      setIsGlitching(false)
      const currentIndex = POD_IDS.indexOf(podId)
      const nextIndex = (currentIndex + 1) % POD_IDS.length
      const newPod = POD_IDS[nextIndex]
      setPodId(newPod)
      setPodStatus("healthy")
      setIsReconnecting(false)
      addLog("INFO", `Started container on ${newPod}`)
      addLog("INFO", "Health check passed - 200 OK")
    }, 6000) // Extended recovery time since server needs to restart
  }

  const getLogColor = (level: LogEntry["level"]) => {
    switch (level) {
      case "INFO":
        return "text-primary"
      case "WARN":
        return "text-amber-500"
      case "ERROR":
        return "text-destructive"
      case "K8S":
        return "text-cyan-400"
      default:
        return "text-primary"
    }
  }

  return (
    <div className="rounded-lg border border-primary/30 bg-card/80 backdrop-blur-sm p-6 h-full flex flex-col holo-panel">
      {/* Header */}
      <div className="flex items-center gap-3 mb-4">
        <div className="p-2 rounded-lg bg-primary/10 border border-primary/30 shadow-[0_0_15px_rgba(34,211,238,0.2)]">
          <Database className="h-5 w-5 text-primary neon-text" />
        </div>
        <div>
          <h2 className="text-lg font-semibold text-foreground font-sans">Service Resilience</h2>
          <p className="text-xs text-primary/70 font-mono tracking-wider">RDS Connection Pool</p>
        </div>
      </div>

      {/* Main Counter - Nixie Tube Style */}
      <div className="flex flex-col items-center justify-center py-4">
        <div className="relative">
          <div className="absolute inset-0 -inset-x-8 -inset-y-4 bg-gradient-to-b from-primary/5 via-primary/10 to-primary/5 rounded-xl blur-xl" />
          <div className="relative text-5xl md:text-6xl font-mono font-bold text-primary tracking-[0.15em] text-center nixie-counter">
            {hitCount.toLocaleString()}
          </div>
          <div className="absolute inset-0 text-5xl md:text-6xl font-mono font-bold text-primary tracking-[0.15em] text-center blur-md opacity-50">
            {hitCount.toLocaleString()}
          </div>
        </div>
        <p className="text-sm text-muted-foreground mt-2 font-sans uppercase tracking-widest">Database Hits</p>
      </div>

      {/* CRT Terminal Log */}
      <div className="mt-4 rounded-lg overflow-hidden crt-screen border border-primary/20 relative">
        <div className="px-3 py-1.5 border-b border-primary/20 flex items-center gap-2 bg-primary/5">
          <div className="flex gap-1.5">
            <div className="w-2 h-2 rounded-full bg-destructive/80" />
            <div className="w-2 h-2 rounded-full bg-amber-500/80" />
            <div className="w-2 h-2 rounded-full bg-accent/80" />
          </div>
          <span className="text-[10px] text-primary/60 font-mono tracking-wider">K8S EVENT LOG</span>
        </div>
        <div
          ref={logContainerRef}
          className="h-28 overflow-y-auto px-3 py-2 font-mono text-[11px] leading-relaxed scrollbar-thin"
        >
          {logs.map((log, i) => (
            <div key={i} className="flex gap-2">
              <span className="text-muted-foreground/60">{log.timestamp}</span>
              <span className={`${getLogColor(log.level)} font-semibold`}>[{log.level}]</span>
              <span className={getLogColor(log.level)}>{log.message}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Pod Status */}
      <div className="mt-4 p-4 rounded-lg bg-secondary/80 border border-primary/20 shadow-[inset_0_0_20px_rgba(34,211,238,0.05)]">
        <div className="flex items-center justify-between mb-3">
          <div className="flex items-center gap-2">
            <Server className="h-4 w-4 text-primary/70" />
            <span className="text-sm text-muted-foreground font-sans">Current Pod:</span>
          </div>
          <div
            className={`flex items-center gap-2 px-3 py-1 rounded text-xs font-mono tracking-wider ${podStatus === "healthy"
                ? "bg-accent/20 text-accent border border-accent/40 shadow-[0_0_10px_rgba(16,185,129,0.3)]"
                : podStatus === "terminated"
                  ? "bg-destructive/20 text-destructive border border-destructive/40 shadow-[0_0_10px_rgba(244,63,94,0.3)]"
                  : "bg-amber-500/20 text-amber-500 border border-amber-500/40 shadow-[0_0_10px_rgba(245,158,11,0.3)]"
              }`}
          >
            {podStatus === "reconnecting" && <RefreshCw className="h-3 w-3 animate-spin" />}
            {podStatus.toUpperCase()}
          </div>
        </div>
        <div
          className={`font-mono text-lg flex items-center gap-2 ${isGlitching ? "text-destructive glitch-text" : "text-primary neon-text"
            }`}
        >
          <span>
            {podStatus === "terminated"
              ? "STATUS: TERMINATING..."
              : podStatus === "reconnecting"
                ? "Failover in progress..."
                : podId}
          </span>
        </div>
      </div>

      {/* Kill Button - Hazard Style */}
      <Button
        onClick={handleKillPod}
        disabled={isReconnecting}
        className={`mt-4 w-full h-14 bg-destructive/20 hover:bg-destructive/40 border-2 border-destructive/60 text-destructive font-mono font-bold text-base tracking-wider transition-all duration-300 disabled:opacity-50 relative overflow-hidden ${isKillActive ? "kill-active" : "hazard-btn"
          }`}
      >
        <Skull className="h-5 w-5 mr-2" />
        {isReconnecting ? "RECONNECTING..." : "KILL POD PROCESS"}
      </Button>

      {/* Info Footer */}
      <p className="text-xs text-muted-foreground text-center mt-3 font-sans">
        Simulates chaos engineering - K8s will auto-failover to healthy replica
      </p>
    </div>
  )
}
