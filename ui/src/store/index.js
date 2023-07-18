import Vue from "vue";
import Vuex from "vuex";
import createPersistedState from "vuex-persistedstate";
import swal from "sweetalert2";

Vue.use(Vuex);

const store = new Vuex.Store({
  state: {
    userAccount: { address: "", publicKey: "" },
    isLoading: false,
    colors: { primary: "" },
    connectedWallet: false,
    loadingZIndex: 0,
  },
  plugins: [createPersistedState()],
  modules: {},
  mutations: {
    connectionState(state, connection) {
      console.log("in commit: ", connection);
      state.userAccount = connection.account;
      state.connectedWallet = connection.connectedWallet;
    },
  },
  actions: {
    setUpListeners(_context, _) {
      window.addEventListener("beforeunload", function (event) {
        store.dispatch("resetState");
      });
    },
    resetState(_context, _) {
      store.commit("connectionState", {
        account: { address: "", publicKey: "" },
        connectedWallet: false,
      });
    },
    async disconnectWallet(_context, _) {
      try {
        store.dispatch("resetState");
        const wallet = await store.dispatch("getAptosWallet");
        await wallet.disconnect();
      } catch (error) {
        console.error("Error disconnecting wallet: ", error);
      }
    },
    // Wallet Connection
    async connectWallet(_context, _) {
      if (store.state.connectedWallet) return;
      try {
        const wallet = await store.dispatch("getAptosWallet");
        const response = await wallet.connect();
        console.log(response); // { address: string, address: string }

        const account = await wallet.account();
        console.log(account); // { address: string, address: string }
        if (account) {
          store.commit("connectionState", {
            account: account,
            connectedWallet: true,
          });
          store.dispatch("setUpListeners");
        }
      } catch (error) {
        console.error(error, typeof error === "object");
        if (
          !(error instanceof Error) &&
          Object.prototype.hasOwnProperty.call(error, "code")
        ) {
          store.dispatch("errorWithCallBackDispatch", {
            dispatchFunctionName: "connectWallet",
            confirmButtonText: "Connect",
            message:
              "Seems like you rejected connecting to your wallet, to continue please connect your wallet",
          });
        }
        console.error("Error connecting user wallet", error.toString());
      }
    },

    getAptosWallet(_context, _) {
      const isPetraInstalled = window.aptos;

      if (isPetraInstalled) {
        return window.aptos;
      } else {
        store.dispatch("errorWithFooter", {
          message: "Seems like you don't have the Petra wallet installed",
          footer: `<a href="https://petra.app/">Download Petra</a>`,
        });
        throw new Error("Petra wallet not installed");
      }
    },

    // Success and Error Messages with Callbacks
    successWithCallBack(_context, message) {
      swal
        .fire({
          position: "top-end",
          icon: "success",
          title: "Success",
          showConfirmButton: true,
          text: message.message,
        })
        .then((results) => {
          if (results.isConfirmed) {
            message.onTap();
          }
        });
    },

    errorWithCallBack(_context, error) {
      swal
        .fire({
          title: "Error!",
          text: error.message,
          icon: "error",
          confirmButtonText: error.confirmButtonText,
        })
        .then((result) => {
          console.error("errorWithCallBack: ", result);
          if (result.isConfirmed) {
            error.callBack();
          }
        });
    },
    errorWithCallBackDispatch(_context, error) {
      swal
        .fire({
          title: "Error!",
          text: error.message,
          icon: "error",
          confirmButtonText: error.confirmButtonText,
        })
        .then((result) => {
          console.error("errorWithCallBack: ", result);
          if (result.isConfirmed) {
            store.dispatch(error.dispatchFunctionName);
          }
        });
    },
    // Other Messages
    success(_context, message) {
      swal.fire({
        position: "top-end",
        icon: "success",
        title: "Success",
        showConfirmButton: false,
        timer: 2500,
        text: message.message,
      });
    },

    warning(_context, warning) {
      swal.fire("Warning", warning.message, "warning").then((result) => {
        if (result.isConfirmed) {
          message.onTap();
        }
      });
    },

    error(_context, error) {
      swal.fire("Error!", error.message, "error").then((result) => {
        if (result.isConfirmed) {
          console.log("leveled");
        }
      });
    },

    successWithFooter(_context, message) {
      swal.fire({
        icon: "success",
        title: "Success",
        text: message.message,
        footer: message.footer,
      });
    },

    errorWithFooter(_context, error) {
      swal.fire({
        icon: "error",
        title: "Error!",
        text: error.message,
        footer: error.footer,
      });
    },
  },
});

export default store;
