import { DashboardHeader } from "@/components/dashboard/header"
import { ResiliencePanel } from "@/components/dashboard/resilience-panel"
import { ScalingPanel } from "@/components/dashboard/scaling-panel"
import { MetricsFooter } from "@/components/dashboard/metrics-footer"

import { StressButton } from "@/components/stress-test-button"

export default function DevOpsDashboard() {
  return (
    <div className="min-h-screen bg-background flex flex-col scanlines vignette">
      {/* Circuit board pattern background */}
      <div className="fixed inset-0 opacity-30 pointer-events-none" style={{
        backgroundImage: `
          linear-gradient(rgba(34, 211, 238, 0.03) 1px, transparent 1px),
          linear-gradient(90deg, rgba(34, 211, 238, 0.03) 1px, transparent 1px),
          radial-gradient(circle at 25px 25px, rgba(34, 211, 238, 0.05) 2px, transparent 2px),
          radial-gradient(circle at 75px 75px, rgba(34, 211, 238, 0.03) 1px, transparent 1px)
        `,
        backgroundSize: '50px 50px, 50px 50px, 100px 100px, 100px 100px'
      }} />

      {/* Hexagonal grid overlay */}
      <div className="fixed inset-0 opacity-10 pointer-events-none" style={{
        backgroundImage: `url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='28' height='49' viewBox='0 0 28 49'%3E%3Cg fillRule='evenodd'%3E%3Cg fill='%2322d3ee' fillOpacity='0.4'%3E%3Cpath d='M13.99 9.25l13 7.5v15l-13 7.5L1 31.75v-15l12.99-7.5zM3 17.9v12.7l10.99 6.34 11-6.35V17.9l-11-6.34L3 17.9zM0 15l12.98-7.5V0h-2v6.35L0 12.69v2.3zm0 18.5L12.98 41v8h-2v-6.85L0 35.81v-2.3zM15 0v7.5L27.99 15H28v-2.31h-.01L17 6.35V0h-2zm0 49v-8l12.99-7.5H28v2.31h-.01L17 42.15V49h-2z'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E")`
      }} />

      {/* Gradient overlay with deeper color */}
      <div className="fixed inset-0 bg-gradient-to-b from-cyan-900/10 via-transparent to-indigo-900/10 pointer-events-none" />

      <div className="relative z-10 flex flex-col min-h-screen">
        <DashboardHeader
          environment={process.env.NEXT_PUBLIC_ENVIRONMENT || "Dev Cluster"}
          version={process.env.NEXT_PUBLIC_BUILD_VERSION || "v1.0.0"}
          commit={process.env.NEXT_PUBLIC_COMMIT_SHA || "HEAD"}
        />

        <main className="flex-1 p-6">
          <div className="flex justify-end mb-4">
            <StressButton />
          </div>
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 h-full">
            <ResiliencePanel />
            <ScalingPanel />
          </div>
        </main>

        <MetricsFooter />
      </div>
    </div>
  )
}
