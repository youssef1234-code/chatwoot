<script>
import { CSAT_RATINGS, NPS_RATINGS } from 'shared/constants/messages';

export default {
  name: 'ReportFiltersRatings',
  props: {
    ratingType: {
      type: String,
      default: 'csat', // 'csat' or 'nps'
    },
  },
  emits: ['ratingFilterSelection'],
  data() {
    let ratings = CSAT_RATINGS;
    
    if (this.ratingType === 'nps') {
      ratings = NPS_RATINGS.map(rating => ({
        ...rating,
        label: rating.value.toString(),
        translationKey: `NPS.RATINGS.${rating.value}`,
      }));
    } else {
      ratings = CSAT_RATINGS.map(option => ({
        ...option,
        label: this.$t(option.translationKey),
      }));
    }

    return {
      selectedOption: null,
      options: ratings.reverse(),
    };
  },
  methods: {
    handleInput(selectedRating) {
      this.$emit('ratingFilterSelection', selectedRating);
    },
  },
};
</script>

<template>
  <div class="multiselect-wrap--small">
    <multiselect
      v-model="selectedOption"
      class="no-margin"
      :option-height="24"
      :placeholder="$t('FORMS.MULTISELECT.SELECT_ONE')"
      :options="options"
      :show-labels="false"
      track-by="value"
      label="label"
      @update:model-value="handleInput"
    />
  </div>
</template>
