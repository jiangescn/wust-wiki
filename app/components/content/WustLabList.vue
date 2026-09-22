<script setup lang="ts">
import LabList from '~/data/coder/labs.json'
import LabItem from '~/xupt/components/unique/LabItem.vue'
</script>

<template>
  <h1 class="center-line">武科大俱乐部</h1>

  <div class="center-line vp-doc">
  </div>

  <section class="lab-list">
    <LabItem v-for="lab in LabList" v-bind="lab" :key="lab.id" />
  </section>
</template>

<style scoped>
.lab-list {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(14rem, 1fr));
  gap: 1rem;
  margin: 2rem auto;
}

.center-line {
  margin: 2em 0 2rem;
  font: revert;
  text-align: center;
}
</style>
