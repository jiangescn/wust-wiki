// Bridge the original header settings without changing Docus's header schema.
export function useBlogComponentConfig() {
  const config = useAppConfig()
  return { ...config, ...config.blogComponents }
}
