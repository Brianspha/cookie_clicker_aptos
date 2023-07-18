<template>
  <!-- App.vue -->

  <v-app>
    <v-app-bar app>
      <v-row align="start" justify="start">
        <v-btn
          v-if="$store.state.connectedWallet"
          class="ma-2"
          :color="$store.state.colors.primary"
          @click="$store.dispatch('disconnectWallet')"
        >
          Disconnect Wallet </v-btn
        ><v-spacer></v-spacer>
        <v-btn
          class="ma-2"
          :color="$store.state.colors.primary"
          @click="
            $store.state.connectedWallet
              ? null
              : $store.dispatch('connectWallet')
          "
        >
          {{
            $store.state.connectedWallet
              ? $store.state.userAccount.address.substring(0, 3) +
                "..." +
                $store.state.userAccount.address.substring(
                  $store.state.userAccount.address.length - 3,
                  $store.state.userAccount.address.length
                )
              : "Connect Wallet"
          }}
        </v-btn></v-row
      >
    </v-app-bar>

    <!-- Sizes your content based upon application components -->
    <v-main>
      <!-- Provides the application the proper gutter -->
      <v-container fluid>
        <!-- If using vue-router -->
        <router-view></router-view>
      </v-container>
      <v-overlay :value="$store.state.isLoading">
        <v-progress-circular indeterminate size="64"></v-progress-circular>
      </v-overlay>
    </v-main>

    <v-footer app>
      <!-- -->
    </v-footer>
  </v-app>
</template>
<script>
export default {
  async beforeMount() {
    await this.$store.dispatch("connectWallet");
    console.log("store.state.userAccount: ", this.$store.state);
  },
};
</script>
<style lang="scss">
#app {
  font-family: Avenir, Helvetica, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-align: center;
  color: #2c3e50;
}

#nav {
  padding: 30px;

  a {
    font-weight: bold;
    color: #2c3e50;

    &.router-link-exact-active {
      color: #42b983;
    }
  }
}
</style>
