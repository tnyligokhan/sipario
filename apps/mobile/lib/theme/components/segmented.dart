// Segment filtresi — ORTAK bileşen (handoff): hap ray, seçilide vurgu dolgu + onay ikonu, diğerleri
// sessiz. Davranış SegmentedButton'la aynı (tek seçim); yalnız görünüm handoff'a uyar. Etiketler düz
// `Text` — testler segmentleri metinle bulur (find.text('Açık'/'Benim')).

import 'package:flutter/material.dart';

import '../tokens.dart';
import '../typography.dart';

class SipSegment<T> {
  const SipSegment({required this.value, required this.label});
  final T value;
  final String label;
}

class SipSegmented<T> extends StatelessWidget {
  const SipSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<SipSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: SipColors.s2,
        border: Border.all(color: SipColors.line),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          for (final s in segments)
            Expanded(child: _Seg<T>(segment: s, selected: s.value == selected, onTap: onChanged)),
        ],
      ),
    );
  }
}

class _Seg<T> extends StatelessWidget {
  const _Seg({required this.segment, required this.selected, required this.onTap});

  final SipSegment<T> segment;
  final bool selected;
  final ValueChanged<T> onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? SipColors.acc : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => onTap(segment.value),
        child: Container(
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(Icons.check, size: 18, color: SipColors.accInk),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  segment.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SipText.badge.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: selected ? SipColors.accInk : SipColors.t2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
