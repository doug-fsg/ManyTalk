import { HorizontalBar } from 'vue-chartjs';

const fontFamily =
  'PlusJakarta,-apple-system,system-ui,BlinkMacSystemFont,"Segoe UI",Roboto,"Helvetica Neue",Arial,sans-serif';

const defaultChartOptions = {
  responsive: true,
  maintainAspectRatio: false,
  legend: {
    display: true,
    position: 'bottom',
    labels: {
      fontFamily,
      padding: 15,
      usePointStyle: true,
      boxWidth: 12,
    },
  },
  tooltips: {
    enabled: true,
    mode: 'point',
    intersect: true,
    backgroundColor: 'rgba(0, 0, 0, 0.85)',
    titleFontFamily: fontFamily,
    bodyFontFamily: fontFamily,
    padding: 10,
    cornerRadius: 6,
    displayColors: false,
    callbacks: {
      title(tooltipItems) {
        return tooltipItems[0].yLabel;
      },
      label(tooltipItem, data) {
        const datasetLabel = data.datasets[tooltipItem.datasetIndex].label || '';
        const value = tooltipItem.xLabel || tooltipItem.value;
        return `${datasetLabel}: ${value}`;
      },
    },
  },
  hover: {
    mode: 'point',
    intersect: true,
    animationDuration: 150,
  },
  animation: {
    duration: 750,
    easing: 'easeOutQuart',
  },
  scales: {
    xAxes: [
      {
        stacked: true,
        ticks: {
          fontFamily,
          beginAtZero: true,
          stepSize: 1,
        },
        gridLines: {
          display: true,
          color: 'rgba(0, 0, 0, 0.05)',
          drawBorder: false,
        },
      },
    ],
    yAxes: [
      {
        stacked: true,
        ticks: {
          fontFamily,
        },
        gridLines: {
          display: false,
          drawBorder: false,
        },
      },
    ],
  },
};

export default {
  extends: HorizontalBar,
  props: {
    collection: {
      type: Object,
      default: () => ({
        labels: [],
        datasets: [],
      }),
    },
    chartOptions: {
      type: Object,
      default: () => ({}),
    },
  },
  watch: {
    collection: {
      handler(newCollection) {
        if (newCollection && newCollection.datasets) {
          this.renderChart(newCollection, {
            ...defaultChartOptions,
            ...this.chartOptions,
          });
        }
      },
      deep: true,
      immediate: false,
    },
  },
  mounted() {
    if (this.collection && this.collection.datasets) {
      this.renderChart(this.collection, {
        ...defaultChartOptions,
        ...this.chartOptions,
      });
    }
  },
};

