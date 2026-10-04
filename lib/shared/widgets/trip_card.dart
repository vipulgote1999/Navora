import 'package:flutter/material.dart';
import 'package:tripmesh/shared/models/trip.dart';

/// P0 card for one trip: name, route, participants `n/m`, status.
///
/// [status] overrides the trip's own status when the caller tracks a
/// liveness-derived value; defaults to `trip.status`.
class TripCard extends StatelessWidget {
  final Trip trip;
  final int memberCount;

  /// Optional status override; falls back to `trip.status`.
  final TripStatus? status;

  const TripCard({
    super.key,
    required this.trip,
    required this.memberCount,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStatus = status ?? trip.status;
    return Semantics(
      label:
          'Trip ${trip.name}, ${trip.origin} to ${trip.destination}, '
          '$memberCount of ${trip.maxParticipants} riders, '
          'status ${effectiveStatus.name}',
      container: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trip.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(trip.origin),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.arrow_forward, size: 16),
                  ),
                  Text(trip.destination),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.people, size: 16),
                  const SizedBox(width: 4),
                  Text('$memberCount/${trip.maxParticipants}'),
                  const SizedBox(width: 12),
                  Chip(label: Text(effectiveStatus.name)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
