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
    project_id: number;
    ids: number[];
    etag: string
}   