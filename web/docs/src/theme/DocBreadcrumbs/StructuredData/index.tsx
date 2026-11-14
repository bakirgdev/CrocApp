import type {Props} from '@theme/DocBreadcrumbs/StructuredData';
import StructuredData from '@theme-original/DocBreadcrumbs/StructuredData';
import type {ReactNode} from 'react';

// Docusaurus writes each BreadcrumbList item as siteConfig.url + href, without
// the trailingSlash the pages are built with, so every item answered with a 301.
// trailingSlash is true and breadcrumb hrefs carry no query or hash.
export default function StructuredDataWrapper({breadcrumbs}: Props): ReactNode {
  const slashed = breadcrumbs.map((item) =>
    item.href && !item.href.endsWith('/') ? {...item, href: `${item.href}/`} : item,
  );
  return <StructuredData breadcrumbs={slashed} />;
}
