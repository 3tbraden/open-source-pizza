export interface NpmRegistryResponse {
    repository: {
        url: string
    }
};

export interface packageObject {
    dependencies: object,
}

export interface DependencyInfo {
    updated: boolean,
    ids: number[],
    etags: any
}
