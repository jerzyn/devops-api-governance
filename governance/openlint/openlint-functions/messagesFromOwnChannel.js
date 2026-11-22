/**
 * api-peak:async15:2026-own-channel-messages
 *
 * AsyncAPI 3: an operation may only use messages defined on its own channel.
 * The built-in OpenLint rules miss this (the AsyncAPI parser catches it).
 */
export default function messagesFromOwnChannel(operation, _opts, context) {
  const channelRef = operation?.channel?.$ref;
  if (!channelRef || !Array.isArray(operation.messages)) return [];
  return operation.messages
    .map((m, i) => ({ ref: m?.$ref, i }))
    .filter(({ ref }) => ref && !ref.startsWith(`${channelRef}/messages/`))
    .map(({ ref, i }) => ({
      message: `Message ${ref} does not belong to channel ${channelRef}.`,
      path: [...context.path, 'messages', i],
    }));
}
