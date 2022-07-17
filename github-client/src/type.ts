export interface NpmRegistryResponse {
    repository: {
        url: string
    }
};

export interface packageObject {
    dependencies: object,
    devDependencies?: object,
}

  
export interface DependencyInfo {
    updated: boolean,
    ids: number[],
    etag: string
}
