import { View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { AppHeader } from "@/components/layout/AppHeader";
import { ActivityFeed } from "@/components/activity/ActivityFeed";

export default function ActivityScreen(): React.JSX.Element {
  return (
    <SafeAreaView className="flex-1 bg-background" edges={["top"]}>
      <View className="flex-1">
        <AppHeader title="Activity" />
        <ActivityFeed />
      </View>
    </SafeAreaView>
  );
}
