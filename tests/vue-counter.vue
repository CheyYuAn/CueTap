<template>
    <div class="counter">
        <p>Count: {{ count }}, Double: {{ double }}</p>
        <button @click="count++">+1</button>
        <button @click="count--">-1</button>
        <button @click="count = 0">Reset</button>
    </div>
</template>
