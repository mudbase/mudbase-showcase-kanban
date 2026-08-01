import { View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { AppHeader } from "@/components/layout/AppHeader";
import { BoardScreenContent } from "@/components/board/BoardScreenContent";

export default function BoardScreen(): React.JSX.Element {
  return (
    <SafeAreaView className="flex-1 bg-background" edges={["top"]}>
      <View className="flex-1">
        <AppHeader title="Team Board" />
        <BoardScreenContent />
      </View>
    </SafeAreaView>
  );
}
