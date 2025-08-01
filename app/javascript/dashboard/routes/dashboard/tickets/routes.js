import { frontendURL } from '../../../helper/URLHelper';
import TicketsWrapper from './TicketsWrapper.vue';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/tickets'),
    name: 'tickets_index',
    component: TicketsWrapper,
    meta: {
      permissions: ['administrator', 'agent', 'custom_role'],
    },
  },
];
