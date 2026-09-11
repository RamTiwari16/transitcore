import { Pipe, PipeTransform } from '@angular/core';

@Pipe({
  name: 'stripHtml',
  standalone: true
})
export class StripHtmlPipe implements PipeTransform {
  transform(value: string): string {
    if (!value) return '';

    // 1. Remove HTML tags
    const withoutTags = value.replace(/<[^>]+>/g, '');

    // 2. Decode HTML entities like &nbsp;, &amp;, &lt;
    const txt = document.createElement('textarea');
    txt.innerHTML = withoutTags;
    return txt.value;
  }
}
