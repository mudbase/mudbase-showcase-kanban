import { AuthGate } from "@/components/auth/AuthGate"
import { BoardView } from "@/components/board/BoardView"

export default function HomePage(): React.JSX.Element {
  return (
    <div className="container max-w-[1400px] py-8">
      <AuthGate>
        <BoardView />
      </AuthGate>
    </div>
  )
}
