<template>
  <v-container fluid class="container">
    <v-img
      :lazy-src="cookieImage"
      :src="cookieImage"
      class="button"
      :class="{ crumbled: cookieCrumbled }"
      @click="crumbleCookie"
      aspect-ratio="1.4"
    >
      <template v-if="!cookieCrumbled">
        <span class="cookie"></span>
      </template>
      <template v-else>
        <template v-for="(crumb, index) in crumbs">
          <transition :key="index" name="float">
            <span
              class="crumb"
              :style="{ top: crumb.top + 'px', left: crumb.left + 'px' }"
            ></span>
          </transition>
          <transition :key="index + Math.random()" name="fade">
            <span
              v-if="showCount"
              class="count"
              :style="{ top: crumb.top + 'px', left: crumb.left + 'px' }"
              >+1</span
            >
          </transition>
        </template>
      </template>
    </v-img>
    <transition name="fade"> </transition>
  </v-container>
</template>

<script>
export default {
  data() {
    return {
      cookieCrumbled: false,
      cookieImage: "https://pngimg.com/d/cookie_PNG13669.png",
      crumbs: [],
      showCount: false,
    };
  },
  methods: {
    crumbleCookie(event) {
      const button = event.target;
      const buttonRect = button.getBoundingClientRect();
      const buttonWidth = buttonRect.width;
      const buttonHeight = buttonRect.height;

      const clickX = event.clientX - buttonRect.left;
      const clickY = event.clientY - buttonRect.top;

      const crumbElement = document.createElement("span");
      crumbElement.classList.add("crumb");
      crumbElement.style.left = clickX + "px";
      crumbElement.style.top = clickY + "px";
      button.appendChild(crumbElement);

      const countElement = document.createElement("span");
      countElement.classList.add("count");
      countElement.style.left = clickX - 15 + "px";
      countElement.style.top = clickY - 15 + "px";
      button.appendChild(countElement);

      this.crumbs.push({
        top: clickY,
        left: clickX,
      });

      this.showCount = true;
      this.cookieCrumbled = true;

      setTimeout(() => {
        crumbElement.remove();
        countElement.remove();
        this.crumbs = [];
        this.showCount = false;
        this.cookieCrumbled = false;
      }, 50);
    },
  },
};
</script>

<style>
.container {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 100vh;
}

.button {
  position: relative;
  display: inline-block;
  padding: 0;
  width: 30vw;
  height: 30vw;
  max-width: 300px;
  max-height: 300px;
  border-radius: 50%;
  background-color: transparent;
  border: none;
  cursor: pointer;
  transition: transform 0.2s;
}

.crumbled {
  transform: scale(0.9);
}

.cookie {
  display: block;
  width: 100%;
  height: 100%;
  background-image: url(https://pngimg.com/d/cookie_PNG13669.png);
  background-repeat: no-repeat;
  background-size: contain;
  transform: rotate(-90deg);
}

.crumb {
  background-image: url(https://pngimg.com/d/cookie_PNG13669.png),
    radial-gradient(#ffffff, #ffffff);
  background-repeat: no-repeat;
  background-size: contain;
  width: 20px;
  height: 20px;
  border-radius: 50%;
  animation: floatAnimation 3s forwards;
  position: absolute;
}

.count {
  position: absolute;
  background-color: transparent;
  color: #ffffff;
  padding: 4px 8px;
  border-radius: 50%;
  font-size: 24px;
  font-weight: bold;
  font-family: "Arial", sans-serif;
  animation: floatAnimation 3s forwards;
  text-shadow: 1px 1px 3px rgba(0, 0, 0, 0.5);
}

@keyframes floatAnimation {
  0% {
    transform: translateY(0);
    opacity: 1;
  }
  100% {
    transform: translateY(-100%);
    opacity: 0;
  }
}

.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.5s;
}

.fade-enter,
.fade-leave-to {
  opacity: 0;
}

.float-enter-active,
.float-leave-active {
  transition: transform 3s, opacity 3s;
}

.float-enter,
.float-leave-to {
  opacity: 1;
}
</style>
