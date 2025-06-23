import { frontendURL } from '../../../../helper/URLHelper';

const ticketsRoutes = accountId => ({
  parentNav: 'tickets',
  routes: ['tickets_index'],
  menuItems: [
    {
      icon: 'clipboard-list',
      label: 'TICKETS.MENU.ALL_TICKETS',
      hasSubMenu: false,
      toState: frontendURL(`accounts/${accountId}/tickets`),
      toStateName: 'tickets_index',
      key: 'tickets_all',
    },
  ],
});

export default ticketsRoutes;
