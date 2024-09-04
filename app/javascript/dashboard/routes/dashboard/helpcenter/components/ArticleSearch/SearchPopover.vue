<script>
import { debounce } from '@chatwoot/utils';
import { useAlert } from 'dashboard/composables';

import SearchHeader from './Header.vue';
import SearchResults from './SearchResults.vue';
import ArticleView from './ArticleView.vue';
import ArticlesAPI from 'dashboard/api/helpCenter/articles';
import { buildPortalArticleURL } from 'dashboard/helper/portalHelper';
import portalMixin from '../../mixins/portalMixin';

export default {
  name: 'ArticleSearchPopover',
  components: {
    SearchHeader,
    SearchResults,
    ArticleView,
  },
  mixins: [portalMixin],
  props: {
    selectedPortalSlug: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      searchQuery: '',
      isLoading: false,
      isLoadingMore: false,
      searchResults: [],
      activeId: '',
      currentPage: 1,
      totalPages: 1,
      debounceSearch: () => {},
    };
  },
  computed: {
    articleViewerUrl() {
      const article = this.activeArticle(this.activeId);
      if (!article) return '';
      const isDark = document.body.classList.contains('dark');

      const url = new URL(article.url);
      url.searchParams.set('show_plain_layout', 'true');

      if (isDark) {
        url.searchParams.set('theme', 'dark');
      }

      return `${url}`;
    },
    searchResultsWithUrl() {
      return this.searchResults.map(article => ({
        ...article,
        localeName: this.localeName(article.category.locale || 'en'),
        url: this.generateArticleUrl(article),
      }));
    },
  },
  mounted() {
    this.fetchArticlesByQuery(this.searchQuery);
    this.debounceSearch = debounce(this.fetchArticlesByQuery, 500, false);
    this.setupScrollListener();
  },
  methods: {
    generateArticleUrl(article) {
      return buildPortalArticleURL(
        this.selectedPortalSlug,
        '',
        '',
        article.slug
      );
    },
    activeArticle(id) {
      return this.searchResultsWithUrl.find(article => article.id === id);
    },
    onSearch(query) {
      this.searchQuery = query;
      this.activeId = '';
      this.currentPage = 1;
      this.searchResults = [];
      this.debounceSearch(query);
    },
    onClose() {
      this.$emit('close');
      this.searchQuery = '';
      this.activeId = '';
      this.searchResults = [];
      this.currentPage = 1;
    },
    async fetchArticlesByQuery(query, append = false) {
      if (this.currentPage > this.totalPages) return; // Stop if no more pages

      try {
        const sort = query ? '' : 'views';
        this.isLoading = !append;
        this.isLoadingMore = append;

        const { data } = await ArticlesAPI.searchArticles({
          portalSlug: this.selectedPortalSlug,
          query,
          page: this.currentPage, // Pass the current page
        });

        if (append) {
          this.searchResults = [...this.searchResults, ...data.payload];
        } else {
          this.searchResults = data.payload;
        }

        this.totalPages = data.meta.total_pages; // Update total pages

        if (append) {
          this.currentPage++;
        }
      } catch (error) {
        // Handle error appropriately
      } finally {
        this.isLoading = false;
        this.isLoadingMore = false;
      }
    },
    handlePreview(id) {
      this.activeId = id;
    },
    onBack() {
      this.activeId = '';
    },
    onInsert(id) {
      const article = this.activeArticle(id || this.activeId);

      this.$emit('insert', article);
      useAlert(this.$t('HELP_CENTER.ARTICLE_SEARCH.SUCCESS_ARTICLE_INSERTED'));
      this.onClose();
    },
    setupScrollListener() {
      const container = this.$el.querySelector('.search-results-container');
      container.addEventListener('scroll', this.handleScroll);
    },
    handleScroll() {
      const container = this.$el.querySelector('.search-results-container');
      if (container.scrollHeight - container.scrollTop === container.clientHeight) {
        // User has scrolled to the bottom
        if (!this.isLoading && this.currentPage <= this.totalPages) {
          this.fetchArticlesByQuery(this.searchQuery, true);
        }
      }
    },
  },
};
</script>

<template>
  <div
    class="fixed top-0 left-0 z-50 flex items-center justify-center w-screen h-screen bg-modal-backdrop-light dark:bg-modal-backdrop-dark"
  >
    <div
      v-on-clickaway="onClose"
      class="flex flex-col px-4 pb-4 rounded-md shadow-md border border-solid border-slate-50 dark:border-slate-800 bg-white dark:bg-slate-900 z-[1000] max-w-[720px] md:w-[20rem] lg:w-[24rem] xl:w-[28rem] 2xl:w-[32rem] h-[calc(100vh-20rem)] max-h-[40rem]"
    >
      <SearchHeader
        :title="$t('HELP_CENTER.ARTICLE_SEARCH.TITLE')"
        class="w-full sticky top-0 bg-[inherit]"
        @close="onClose"
        @search="onSearch"
      />

      <ArticleView
        v-if="activeId"
        :url="articleViewerUrl"
        @back="onBack"
        @insert="onInsert"
      />
      <div class="search-results-container overflow-y-auto" v-else>
        <SearchResults
          :search-query="searchQuery"
          :is-loading="isLoading"
          :portal-slug="selectedPortalSlug"
          :articles="searchResultsWithUrl"
          @preview="handlePreview"
          @insert="onInsert"
        />

        <!-- Spinner for loading more articles -->
        <div v-if="isLoadingMore" class="loading-more-spinner flex justify-center items-center py-4">
          <div class="spinner"></div>
          <span class="ml-2">Loading more articles...</span>
        </div>
      </div>

    </div>
  </div>
</template>
